import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../router/auth_session.dart';
import 'realtime_service.dart';

/// WHEN the live connection runs. No page has to think about it.
///
/// ```
/// logged in             ──► realtime.start()
/// logged out            ──► realtime.stop()
/// app back in front     ──► realtime.reconnectNow()   (the OS often kills
/// network back (wifi/4G)──► realtime.reconnectNow()    sockets in background)
/// app minimized         ──► onBackground()  POST /chats/presence/background
/// app back in front     ──► onForeground()  POST /chats/presence/foreground
/// ```
///
/// The two beacons (5.6) make a minimized phone count as OFFLINE at once,
/// instead of after ~30 s of missed heartbeats. That matters for calls
/// (Steps 6–7): the server rings an OFFLINE phone by push.
class RealtimeLifecycle with WidgetsBindingObserver {
  RealtimeLifecycle({
    required AuthSession session,
    required RealtimeService realtime,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    Future<void> Function()? onBackground,
    Future<void> Function()? onForeground,
  }) : _session = session,
       _realtime = realtime,
       _connectivityChanges = connectivityChanges,
       _onBackground = onBackground,
       _onForeground = onForeground;

  final AuthSession _session;
  final RealtimeService _realtime;
  final Stream<List<ConnectivityResult>>? _connectivityChanges;
  final Future<void> Function()? _onBackground;
  final Future<void> Function()? _onForeground;
  StreamSubscription<List<ConnectivityResult>>? _network;

  /// Call once at start-up (bootstrap).
  void attach() {
    _session.addListener(_onSession);
    WidgetsBinding.instance.addObserver(this);
    _network = (_connectivityChanges ?? Connectivity().onConnectivityChanged)
        .listen((results) {
          if (results.any((r) => r != ConnectivityResult.none)) {
            _realtime.reconnectNow();
          }
        });
    _onSession(); // already logged in (auto-login ran before)?
  }

  void detach() {
    _session.removeListener(_onSession);
    WidgetsBinding.instance.removeObserver(this);
    _network?.cancel();
  }

  void _onSession() {
    if (!_session.isAuthenticated) return _realtime.stop();
    _realtime.start();
    // Logged in (or auto-login at a cold start) WITH the app on screen →
    // say "foreground" once. The server keeps a "minimized" mark until a
    // foreground beacon clears it; a phone that was minimized, then killed,
    // then opened again never goes paused → resumed, so without this it
    // stays OFFLINE for everyone (no 🟢) although it is open (R6 bug).
    // Not on screen (a killed app woken by a push in the background) → no
    // beacon: it must stay OFFLINE so the next call still rings by push.
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      unawaited(_onForeground?.call()); // best effort
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_session.isAuthenticated) return; // logged out: nothing to tell
    switch (state) {
      case AppLifecycleState.resumed:
        _realtime.reconnectNow();
        unawaited(_onForeground?.call()); // best effort
      case AppLifecycleState.paused:
        unawaited(_onBackground?.call()); // best effort
      default:
        break; // inactive / hidden / detached: in between, do nothing
    }
  }
}
