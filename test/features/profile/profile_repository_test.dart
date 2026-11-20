import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:erp_mobile/core/network/api_endpoints.dart';
import 'package:erp_mobile/core/network/app_service.dart';
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/storage/user_cache.dart';
import 'package:erp_mobile/features/profile/repository/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake server that answers per PATH: path → (status, data).
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> received = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    received.add(options);
    final (status, data) = routes[options.path] ?? (404, null);
    final ok = status >= 200 && status < 300;
    return ResponseBody.fromString(
      jsonEncode({
        'success': ok,
        'message': ok ? 'Success' : 'Not found',
        'data': data,
        'errorCode': ok ? null : 'NOT_FOUND',
        'traceId': 't',
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeServer server;
  late ProfileRepository repo;
  late UserCache userCache;

  const userJson = {
    'id': 7,
    'email': 'v@x.com',
    'fullName': 'Vanyda',
    'phone': null,
    'avatarUrl': '/uploads/user.jpg',
  };
  const employeeJson = {
    'id': 3,
    'employeeNo': 'E-003',
    'position': 'Developer',
    'department': 'IT',
    'phone': '012345678',
    'hireDate': '2024-01-15',
    'avatarUrl': '/uploads/emp.jpg',
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({}); // empty cache by default
    userCache = UserCache(await SharedPreferences.getInstance());
    server = _FakeServer();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    repo = ProfileRepository(
      appService: AppService(dio, hasInternet: () async => true),
      userCache: userCache,
    );
  });

  List<String> paths() => [for (final r in server.received) r.path];

  group('user cached at login (normal)', () {
    setUp(() => userCache.save(userJson));

    test('ONE request: /employees/me; employee wins photo + phone', () async {
      server.routes[ApiEndPoint.employeesMe] = (200, employeeJson);

      final profile = (await repo.loadProfile()).getOrElse(
        () => throw StateError('expected Right'),
      );

      expect(paths(), [ApiEndPoint.employeesMe]); // no /users/me
      expect(profile.user.id, '7'); // from the cache
      expect(profile.email, 'v@x.com');
      expect(profile.employee!.employeeNo, 'E-003');
      expect(profile.employee!.hireDate, DateTime(2024, 1, 15));
      expect(profile.avatarUrl, '/uploads/emp.jpg');
      expect(profile.phone, '012345678');
      expect(profile.displayName, 'Vanyda'); // employee has no name → user's
    });

    test('employee 404 → fresh /users/me, profile WITHOUT employee', () async {
      server.routes[ApiEndPoint.me] = (
        200,
        {...userJson, 'fullName': 'Vanyda K.'}, // changed since login
      ); // employeesMe → 404

      final profile = (await repo.loadProfile()).getOrElse(
        () => throw StateError('expected Right'),
      );

      expect(paths(), [ApiEndPoint.employeesMe, ApiEndPoint.me]);
      expect(profile.employee, isNull);
      expect(profile.displayName, 'Vanyda K.');
      expect(userCache.read()!['fullName'], 'Vanyda K.'); // re-cached
    });

    test(
      'employee 404 + /users/me fails → still shows the cached user',
      () async {
        server.routes[ApiEndPoint.me] = (500, null); // employeesMe → 404

        final profile = (await repo.loadProfile()).getOrElse(
          () => throw StateError('expected Right'),
        );

        expect(profile.displayName, 'Vanyda');
        expect(profile.avatarUrl, '/uploads/user.jpg');
      },
    );

    test('employee 500 → Left (no half page)', () async {
      server.routes[ApiEndPoint.employeesMe] = (500, null);

      final result = await repo.loadProfile();

      expect(result.fold((e) => e.statusCode, (_) => null), 500);
    });
  });

  group('no cached user (session from before the cache)', () {
    test('both requests together, and the user gets cached', () async {
      server.routes
        ..[ApiEndPoint.me] = (200, userJson)
        ..[ApiEndPoint.employeesMe] = (200, employeeJson);

      final result = await repo.loadProfile();

      expect(result.isRight(), isTrue);
      expect(
        paths(),
        unorderedEquals([ApiEndPoint.me, ApiEndPoint.employeesMe]),
      );
      expect(userCache.read()!['email'], 'v@x.com');
    });

    test('user fails → Left (nothing to show)', () async {
      server.routes
        ..[ApiEndPoint.me] = (500, null)
        ..[ApiEndPoint.employeesMe] = (200, employeeJson);

      final result = await repo.loadProfile();

      expect(result.fold((e) => e, (_) => null), isA<ServerError>());
      expect(userCache.read(), isNull);
    });
  });

  test('employee name + phone win over the (maybe old) cached user', () async {
    await userCache.save({...userJson, 'phone': '099000000'});
    server.routes[ApiEndPoint.employeesMe] = (
      200,
      {...employeeJson, 'fullName': 'Krouch Vanyda'},
    );

    final profile = (await repo.loadProfile()).getOrElse(
      () => throw StateError('expected Right'),
    );

    expect(profile.displayName, 'Krouch Vanyda');
    expect(profile.phone, '012345678');
  });

  // ─────────────── Step 4.2: avatar ───────────────

  group('avatar', () {
    late File photo;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('avatar');
      photo = File('${dir.path}/me.PNG')..writeAsBytesSync([1, 2, 3]);
      server.routes
        ..[ApiEndPoint.me] = (200, userJson)
        ..[ApiEndPoint.employeesMe] = (200, employeeJson);
    });

    test(
      'upload → multipart "file" (image type) → reloads the profile',
      () async {
        server.routes[ApiEndPoint.employeesMeAvatar] = (200, null);

        final result = await repo.uploadAvatar(photo.path);

        final upload = server.received.firstWhere(
          (r) => r.path == ApiEndPoint.employeesMeAvatar,
        );
        expect(upload.method, 'POST');
        final form = upload.data as FormData;
        expect(form.files.single.key, 'file');
        expect(form.files.single.value.filename, 'me.PNG');
        expect(form.files.single.value.contentType.toString(), 'image/png');
        // then the fresh profile
        expect(result.isRight(), isTrue);
        expect(server.received.last.path, isNot(ApiEndPoint.employeesMeAvatar));
      },
    );

    test('upload fails (413 too big) → Left, no reload', () async {
      server.routes[ApiEndPoint.employeesMeAvatar] = (413, null);

      final result = await repo.uploadAvatar(photo.path);

      expect(result.fold((e) => e.statusCode, (_) => null), 413);
      expect(server.received.length, 1); // only the upload
    });

    test('remove → DELETE → reloads the profile', () async {
      server.routes[ApiEndPoint.employeesMeAvatar] = (200, null);

      final result = await repo.removeAvatar();

      expect(server.received.first.method, 'DELETE');
      expect(result.isRight(), isTrue);
    });
  });
}
