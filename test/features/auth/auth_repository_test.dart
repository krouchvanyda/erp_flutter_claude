import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:erp_mobile/core/network/app_service.dart';
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/network/token_storage.dart';
import 'package:erp_mobile/core/router/auth_session.dart';
import 'package:erp_mobile/features/auth/repository/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeServer implements HttpClientAdapter {
  int status = 200;
  Object? body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> env(Object? data, {bool success = true, String? msg}) => {
  'success': success,
  'message': msg ?? 'Success',
  'data': data,
  'errorCode': success ? null : 'UNAUTHORIZED',
  'traceId': 't',
};

void main() {
  late _FakeServer server;
  late TokenStorage storage;
  late AuthSession session;
  late AuthRepository repo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    server = _FakeServer();
    storage = TokenStorage(const FlutterSecureStorage());
    session = AuthSession();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    repo = AuthRepository(
      appService: AppService(dio, hasInternet: () async => true),
      tokenStorage: storage,
      session: session,
    );
  });

  test('success → returns user, SAVES tokens, OPENS the session', () async {
    server.body = env({
      'accessToken': 'a1',
      'accessTokenExpiresAt': '2026-11-19T10:00:00Z',
      'refreshToken': 'r1',
      'refreshTokenExpiresAt': '2026-12-19T10:00:00Z',
      'user': {
        'id': 7,
        'email': 'v@x.com',
        'fullName': 'Vanyda',
        'phone': '012345678',
        'avatarUrl': null,
      },
    });

    final result = await repo.login(email: ' v@x.com ', password: 'secret');

    final user = result.getOrElse(() => throw StateError('expected Right'));
    expect(user.id, '7'); // number → string
    expect(user.displayName, 'Vanyda');
    expect(user.phone, '012345678');
    expect(user.avatarUrl, isNull);
    expect((await storage.read())!.accessToken, 'a1');
    expect(session.isAuthenticated, isTrue);
    expect(server.last!.data, {'email': 'v@x.com', 'password': 'secret'});
  });

  test(
    'wrong password (401) → Left, NO tokens, session stays closed',
    () async {
      server
        ..status = 401
        ..body = env(null, success: false, msg: 'Invalid email or password');

      final result = await repo.login(email: 'v@x.com', password: 'wrong1');

      expect(result.isLeft(), isTrue);
      expect(await storage.read(), isNull);
      expect(session.isAuthenticated, isFalse);
    },
  );

  test('400 validation → ServerError with fieldErrors', () async {
    server
      ..status = 400
      ..body = {
        ...env(
          {
            'fieldErrors': {'email': 'must be a well-formed email address'},
          },
          success: false,
          msg: 'Validation failed',
        ),
        'errorCode': 'VALIDATION_ERROR',
      };

    final result = await repo.login(email: 'bad', password: 'secret');
    final error = result.fold((e) => e, (_) => null) as ServerError;

    expect(error.fieldErrors['email'], 'must be a well-formed email address');
  });
}
