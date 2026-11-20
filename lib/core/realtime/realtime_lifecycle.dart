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
/// ```
class RealtimeLifecycle with WidgetsBindingObserver {
  RealtimeLifecycle({
    required AuthSession session,
    required RealtimeService realtime,
    Stream<List<ConnectivityResult>>? connectivityChanges,
  }) : _session = session,
       _realtime = realtime,
       _connectivityChanges = connectivityChanges;

  final AuthSession _session;
  final RealtimeService _realtime;
  final Stream<List<ConnectivityResult>>? _connectivityChanges;
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

  void _onSession() =>
      _session.isAuthenticated ? _realtime.start() : _realtime.stop();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _realtime.reconnectNow();
  }
}
