import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:erp_mobile/core/realtime/realtime_connection.dart';
import 'package:erp_mobile/core/realtime/realtime_lifecycle.dart';
import 'package:erp_mobile/core/realtime/realtime_service.dart';
import 'package:erp_mobile/core/router/auth_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopConnection implements RealtimeConnection {
  @override
  void Function() subscribe(String d, void Function(String?) onMessage) =>
      () {};
  @override
  void send(String destination, String body) {}
  @override
  void close() {}
}

/// The presence beacons (5.6) + the R6 fix: login while on screen → foreground.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late AuthSession session;
  late RealtimeService realtime;
  late RealtimeLifecycle lifecycle;
  late StreamController<List<ConnectivityResult>> network;
  late int foreground;
  late int background;

  setUp(() {
    session = AuthSession();
    network = StreamController();
    foreground = 0;
    background = 0;
    realtime = RealtimeService(
      url: 'ws://test/realtime',
      accessToken: () async => 'tok',
      connector: ({required url, required token, required onLost}) async =>
          _NoopConnection(),
    );
    lifecycle = RealtimeLifecycle(
      session: session,
      realtime: realtime,
      connectivityChanges: network.stream,
      onForeground: () async => foreground++,
      onBackground: () async => background++,
    );
  });

  tearDown(() {
    lifecycle.detach();
    realtime.stop();
    network.close();
  });

  test('login while the app is on screen → foreground beacon once', () {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    lifecycle.attach();
    expect(foreground, 0); // logged out: nothing to tell

    session.markAuthenticated();
    expect(foreground, 1);
  });

  test('already logged in at a cold start, on screen → foreground', () {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    session.markAuthenticated(); // auto-login ran before attach
    lifecycle.attach();
    expect(foreground, 1);
  });

  test(
    'woken in the background (not on screen) → NO foreground (stay OFFLINE for push)',
    () {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      session.markAuthenticated();
      lifecycle.attach();
      expect(foreground, 0);
    },
  );

  test('minimize → background · back in front → foreground', () {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    session.markAuthenticated();
    lifecycle.attach();
    foreground = 0;

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(background, 1);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(foreground, 1);
  });
}
