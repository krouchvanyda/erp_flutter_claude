import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:erp_mobile/core/network/api_endpoints.dart';
import 'package:erp_mobile/core/network/app_service.dart';
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/features/profile/repository/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake server that answers per PATH: path → (status, data).
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

  setUp(() {
    server = _FakeServer();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    repo = ProfileRepository(
      appService: AppService(dio, hasInternet: () async => true),
    );
  });

  test(
    'user + employee → both, employee wins avatar, user→employee phone',
    () async {
      server.routes
        ..[ApiEndPoint.me] = (200, userJson)
        ..[ApiEndPoint.employeesMe] = (200, employeeJson);

      final profile = (await repo.loadProfile()).getOrElse(
        () => throw StateError('expected Right'),
      );

      expect(profile.user.id, '7');
      expect(profile.employee!.employeeNo, 'E-003');
      expect(profile.employee!.hireDate, DateTime(2024, 1, 15));
      expect(profile.avatarUrl, '/uploads/emp.jpg'); // employee first
      expect(profile.phone, '012345678'); // user has none → employee's
    },
  );

  test(
    'employee 404 (no linked employee) → profile WITHOUT employee',
    () async {
      server.routes[ApiEndPoint.me] = (200, userJson); // employeesMe → 404

      final profile = (await repo.loadProfile()).getOrElse(
        () => throw StateError('expected Right'),
      );

      expect(profile.employee, isNull);
      expect(profile.avatarUrl, '/uploads/user.jpg');
    },
  );

  test('user fails → Left (nothing to show)', () async {
    server.routes
      ..[ApiEndPoint.me] = (500, null)
      ..[ApiEndPoint.employeesMe] = (200, employeeJson);

    final result = await repo.loadProfile();

    expect(result.fold((e) => e, (_) => null), isA<ServerError>());
  });
}
