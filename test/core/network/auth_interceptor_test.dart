import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:erp_mobile/core/network/api_endpoints.dart';
import 'package:erp_mobile/core/network/auth_interceptor.dart';
import 'package:erp_mobile/core/network/auth_tokens.dart';
import 'package:erp_mobile/core/network/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Reply = ({int status, Object? body});

/// A fake server that answers per path and remembers what it received.
class _FakeServer implements HttpClientAdapter {
  final Map<String, Reply Function(RequestOptions)> routes = {};
  final List<RequestOptions> received = [];
  DioExceptionType? refreshThrows;

  int calls(String path) => received.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    received.add(options);
    if (options.path == ApiEndPoint.refresh && refreshThrows != null) {
      throw DioException(requestOptions: options, type: refreshThrows!);
    }
    final reply = routes[options.path]!(options);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> env(Object? data, {bool success = true}) => {
  'success': success,
  'message': success ? 'Success' : 'Unauthorized',
  'data': data,
  'errorCode': success ? null : 'UNAUTHORIZED',
  'traceId': 't',
};

const oldPair = AuthTokens(accessToken: 'old-a', refreshToken: 'old-r');

void main() {
  late _FakeServer server;
  late TokenStorage storage;
  late Dio dio;
  late int sessionExpired;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = TokenStorage(const FlutterSecureStorage());
    server = _FakeServer();
    sessionExpired = 0;

    final refreshDio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server
      ..interceptors.add(
        AuthInterceptor(
          tokenStorage: storage,
          refreshDio: refreshDio,
          onSessionExpired: () => sessionExpired++,
        ),
      );

    // /me: OK only with the NEW token.
    server.routes[ApiEndPoint.me] = (o) =>
        o.headers['Authorization'] == 'Bearer new-a'
        ? (status: 200, body: env({'name': 'Vanyda'}))
        : (status: 401, body: env(null, success: false));
    // refresh: accepts only the OLD refresh token, returns a NEW pair.
    server.routes[ApiEndPoint.refresh] = (o) =>
        (o.data as Map)['refreshToken'] == 'old-r'
        ? (
            status: 200,
            body: env({'accessToken': 'new-a', 'refreshToken': 'new-r'}),
          )
        : (status: 401, body: env(null, success: false));
    // login: wrong password → 401 (like the real backend).
    server.routes[ApiEndPoint.login] = (_) =>
        (status: 401, body: env(null, success: false));
  });

  test('adds "Authorization: Bearer <access>" to protected requests', () async {
    await storage.write(oldPair);
    server.routes[ApiEndPoint.me] = (_) => (status: 200, body: env({}));

    await dio.get<Object?>(ApiEndPoint.me);

    expect(server.received.single.headers['Authorization'], 'Bearer old-a');
  });

  test('public endpoints never get a token', () async {
    await storage.write(oldPair);
    server.routes[ApiEndPoint.health] = (_) => (status: 200, body: env({}));

    await dio.get<Object?>(ApiEndPoint.health);

    expect(server.received.single.headers['Authorization'], isNull);
  });

  test('401 → refresh → save new pair → retry succeeds', () async {
    await storage.write(oldPair);

    final response = await dio.get<Object?>(ApiEndPoint.me);

    expect(response.statusCode, 200);
    expect(server.calls(ApiEndPoint.refresh), 1);
    expect((await storage.read())!.refreshToken, 'new-r'); // rotated
    expect(sessionExpired, 0);
  });

  test('3 parallel 401s → only ONE refresh', () async {
    await storage.write(oldPair);

    await Future.wait([
      dio.get<Object?>(ApiEndPoint.me),
      dio.get<Object?>(ApiEndPoint.me),
      dio.get<Object?>(ApiEndPoint.me),
    ]);

    expect(server.calls(ApiEndPoint.refresh), 1);
  });

  test('refresh rejected → tokens cleared + session expired', () async {
    await storage.write(
      const AuthTokens(accessToken: 'old-a', refreshToken: 'dead-r'),
    );

    await expectLater(
      dio.get<Object?>(ApiEndPoint.me),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(await storage.read(), isNull);
    expect(sessionExpired, 1);
  });

  test('refresh fails (offline) → tokens KEPT, no logout', () async {
    await storage.write(oldPair);
    server.refreshThrows = DioExceptionType.connectionError;

    await expectLater(
      dio.get<Object?>(ApiEndPoint.me),
      throwsA(isA<DioException>()),
    );
    expect(await storage.read(), oldPair);
    expect(sessionExpired, 0);
  });

  test('no tokens at all + 401 → session expired, no refresh call', () async {
    await expectLater(
      dio.get<Object?>(ApiEndPoint.me),
      throwsA(isA<DioException>()),
    );
    expect(server.calls(ApiEndPoint.refresh), 0);
    expect(sessionExpired, 1);
  });

  test('wrong password on login (401) → NO refresh, NO logout', () async {
    await storage.write(oldPair);

    await expectLater(
      dio.post<Object?>(
        ApiEndPoint.login,
        data: {'email': 'a', 'password': 'b'},
      ),
      throwsA(isA<DioException>()),
    );
    expect(server.calls(ApiEndPoint.refresh), 0);
    expect(sessionExpired, 0);
    expect(await storage.read(), oldPair);
  });

  test('retried request that still gets 401 is not retried again', () async {
    await storage.write(oldPair);
    server.routes[ApiEndPoint.me] = (_) =>
        (status: 401, body: env(null, success: false));

    await expectLater(
      dio.get<Object?>(ApiEndPoint.me),
      throwsA(isA<DioException>()),
    );
    expect(server.calls(ApiEndPoint.refresh), 1); // not an endless loop
    expect(server.calls(ApiEndPoint.me), 2); // original + one retry
  });
}
