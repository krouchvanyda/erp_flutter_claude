import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:erp_mobile/core/network/api_endpoints.dart';
import 'package:erp_mobile/core/network/auth_tokens.dart';
import 'package:erp_mobile/core/network/token_refresher.dart';
import 'package:erp_mobile/core/network/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Refresh endpoint: accepts only the CURRENT refresh token (rotation).
class _RefreshServer implements HttpClientAdapter {
  String validRefresh = 'r1';
  int calls = 0;
  Completer<void>? hold;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    await hold?.future;
    final sent = (options.data as Map)['refreshToken'];
    final ok = options.path == ApiEndPoint.refresh && sent == validRefresh;
    if (ok) validRefresh = 'r${calls + 1}'; // rotate: the old one dies
    return ResponseBody.fromString(
      jsonEncode({
        'success': ok,
        'message': ok ? 'Success' : 'Refresh token not recognised',
        'data': ok
            ? {'accessToken': 'a${calls + 1}', 'refreshToken': validRefresh}
            : null,
      }),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RefreshServer server;
  late TokenStorage storage;
  late TokenRefresher refresher;
  late int expired;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = TokenStorage(const FlutterSecureStorage());
    server = _RefreshServer();
    expired = 0;
    refresher = TokenRefresher(
      tokenStorage: storage,
      refreshDio: Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = server,
      onSessionExpired: () => expired++,
    );
    await storage.write(
      const AuthTokens(accessToken: 'a1', refreshToken: 'r1'),
    );
  });

  test(
    'socket + REST refresh at the same time → ONE call, no logout',
    () async {
      server.hold = Completer<void>();
      final a = refresher.refresh();
      final b = refresher.refresh(); // joins the running one
      server.hold!.complete();

      final results = await Future.wait([a, b]);

      expect(server.calls, 1);
      expect(results.every((r) => r is RefreshOk), isTrue);
      expect(expired, 0); // a 2nd call with the dead r1 would have logged out
      expect((await storage.read())!.accessToken, 'a2');
    },
  );

  test('validTokens: still valid for > 60 s → no refresh', () async {
    await storage.write(
      AuthTokens(
        accessToken: 'a1',
        refreshToken: 'r1',
        accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );

    expect((await refresher.validTokens())!.accessToken, 'a1');
    expect(server.calls, 0);
  });

  test('validTokens: expires in 30 s → refresh first', () async {
    await storage.write(
      AuthTokens(
        accessToken: 'a1',
        refreshToken: 'r1',
        accessTokenExpiresAt: DateTime.now().add(const Duration(seconds: 30)),
      ),
    );

    expect((await refresher.validTokens())!.accessToken, 'a2');
    expect(server.calls, 1);
  });

  test('refused refresh token → tokens cleared + session expired', () async {
    server.validRefresh = 'something-else';

    expect(await refresher.refresh(), isA<RefreshRejected>());
    expect(await storage.read(), isNull);
    expect(expired, 1);
  });
}
