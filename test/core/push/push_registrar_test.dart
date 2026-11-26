import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:erp_mobile/core/network/api_endpoints.dart';
import 'package:erp_mobile/core/network/app_service.dart';
import 'package:erp_mobile/core/push/device_id_store.dart';
import 'package:erp_mobile/core/push/push_messaging.dart';
import 'package:erp_mobile/core/push/push_registrar.dart';
import 'package:erp_mobile/core/router/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPush extends Mock implements PushMessaging {}

/// Answers every request with an empty success envelope and remembers it.
class _FakeServer implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'ok', 'data': null}),
      200,
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
  late _MockPush push;
  late AuthSession session;
  late StreamController<String> refresh;
  late DeviceIdStore ids;
  late PushRegistrar registrar;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ids = DeviceIdStore(await SharedPreferences.getInstance());
    server = _FakeServer();
    push = _MockPush();
    session = AuthSession();
    refresh = StreamController<String>.broadcast();
    when(() => push.requestPermission()).thenAnswer((_) async {});
    when(() => push.token()).thenAnswer((_) async => 'fcm-1');
    when(() => push.onTokenRefresh).thenAnswer((_) => refresh.stream);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    registrar = PushRegistrar(
      appService: AppService(dio, hasInternet: () async => true),
      session: session,
      deviceIds: ids,
      messaging: push,
      platform: 'android',
    );
  });

  tearDown(() async {
    registrar.detach();
    await refresh.close();
  });

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('DeviceIdStore: made once, the same id every time', () async {
    final first = ids.id();
    expect(first, isNotEmpty);
    expect(ids.id(), first);
    final again = DeviceIdStore(await SharedPreferences.getInstance());
    expect(again.id(), first); // saved: the same after a restart
  });

  test('logged out → nothing is sent', () async {
    registrar.attach();
    await tick();
    expect(server.requests, isEmpty);
  });

  test(
    'login → permission → POST /me/devices {deviceId, token, platform}',
    () async {
      registrar.attach();
      session.markAuthenticated();
      await tick();
      await tick();
      verify(() => push.requestPermission()).called(1);
      final r = server.requests.single;
      expect(r.method, 'POST');
      expect(r.path, ApiEndPoint.myDevices);
      expect(r.data, {
        'deviceId': ids.id(),
        'fcmToken': 'fcm-1',
        'platform': 'android',
      });
    },
  );

  test('already logged in when attached (auto-login) → registers', () async {
    session.markAuthenticated();
    registrar.attach();
    await tick();
    await tick();
    expect(server.requests.single.path, ApiEndPoint.myDevices);
  });

  test(
    'token refreshed while logged in → saved again; logged out → not',
    () async {
      session.markAuthenticated();
      registrar.attach();
      await tick();
      await tick();
      refresh.add('fcm-2');
      await tick();
      expect(server.requests.last.data['fcmToken'], 'fcm-2');

      session.markLoggedOut();
      final before = server.requests.length;
      refresh.add('fcm-3');
      await tick();
      expect(server.requests.length, before);
    },
  );

  test('start-up: login hook + iOS onTokenRefresh with the SAME token '
      'at once → ONE POST (no duplicate-key 500)', () async {
    session.markAuthenticated();
    registrar.attach();
    refresh.add('fcm-1'); // iOS emits the current token at start
    await tick();
    await tick();
    expect(server.requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  test('the same token again later → not sent again; after logout + '
      'login → sent again', () async {
    session.markAuthenticated();
    registrar.attach();
    await tick();
    await tick();
    refresh.add('fcm-1');
    await tick();
    expect(server.requests, hasLength(1));

    session.markLoggedOut();
    session.markAuthenticated(); // maybe another user on this phone
    await tick();
    await tick();
    expect(server.requests, hasLength(2));
  });

  test(
    'no FCM token (no Play services / APNs) → no request, no crash',
    () async {
      when(() => push.token()).thenAnswer((_) async => null);
      session.markAuthenticated();
      registrar.attach();
      await tick();
      await tick();
      expect(server.requests, isEmpty);
    },
  );

  test('unregister → DELETE /me/devices/{deviceId}', () async {
    await registrar.unregister();
    final r = server.requests.single;
    expect(r.method, 'DELETE');
    expect(r.path, ApiEndPoint.myDevice(ids.id()));
  });
}
