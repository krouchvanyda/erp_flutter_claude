import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'realtime_event.dart';
import 'stomp_connection.dart';

/// Is the live connection up? (The inbox shows "Connecting…" when not.)
enum RealtimeStatus {
  /// Not started (logged out).
  stopped,

  /// Trying to connect, or waiting to try again.
  connecting,
  connected,
}

/// The app's ONE live connection to the server (STOMP over WebSocket).
///
/// It knows STOMP, tokens and reconnecting — NOTHING about chat. Features
/// ask for a destination and get a stream of [RealtimeEvent]s.
///
/// ```
/// start() ──► token ──► connect ──► connected ──► (re)subscribe all
///               ▲                       │ drops
///               └── wait 1,2,4…30 s ◄────┘   reconnectNow() skips the wait
/// ```
///
/// - **Fresh token every try** ([tokens] refreshes it when it's about to
///   expire).
/// - **Subscriptions survive reconnects**: a page subscribes once; after a
///   drop we subscribe again on the new connection.
/// - **[reconnected]**: events sent while we were down are LOST. Listeners
///   reload their data when this fires (catch-up).
class RealtimeService {
  RealtimeService({
    required this.url,
    required Future<String?> Function() accessToken,
    StompConnector connector = connectStomp,
    Duration Function(int attempt)? backoff,
  }) : _accessToken = accessToken,
       _connector = connector,
       _backoff = backoff ?? defaultBackoff;

  final String url;
  final Future<String?> Function() _accessToken;
  final StompConnector _connector;
  final Duration Function(int attempt) _backoff;

  /// 1 s, 2 s, 4 s, 8 s, 16 s, then 30 s forever.
  static Duration defaultBackoff(int attempt) =>
      Duration(seconds: min(30, 1 << min(attempt, 5)));

  final ValueNotifier<RealtimeStatus> status = ValueNotifier(
    RealtimeStatus.stopped,
  );

  final _reconnected = StreamController<void>.broadcast();

  /// Fires after a connection comes BACK (not the first one).
  Stream<void> get reconnected => _reconnected.stream;

  /// destination → its stream + the "stop" of its current STOMP subscription.
  final Map<String, _Topic> _topics = {};

  StompConnection? _connection;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _running = false;
  bool _connecting = false;
  bool _hadConnection = false;

  /// Each connect try gets a number. A late answer from an OLD try (after
  /// stop / a newer try) is thrown away.
  int _generation = 0;

  /// Events from [destination] ("/user/queue/inbox").
  ///
  /// Many listeners can share one destination; the STOMP subscription is made
  /// when the first one listens and removed when the last one cancels.
  Stream<RealtimeEvent> subscribe(String destination) {
    final topic = _topics.putIfAbsent(destination, () {
      late final _Topic t;
      t = _Topic(
        StreamController<RealtimeEvent>.broadcast(
          onListen: () => _attach(destination, t),
          onCancel: () {
            t.detach();
            _topics.remove(destination);
            t.controller.close();
          },
        ),
      );
      return t;
    });
    return topic.controller.stream;
  }

  /// Logged in → go online (and keep trying).
  void start() {
    if (_running) return;
    _running = true;
    _attempt = 0;
    _connect();
  }

  /// Logged out → close everything, no more tries.
  void stop() {
    _running = false;
    _generation++;
    _retryTimer?.cancel();
    _closeConnection();
    _hadConnection = false;
    _connecting = false;
    status.value = RealtimeStatus.stopped;
  }

  /// App came to the front / network is back → try NOW, don't wait.
  void reconnectNow() {
    if (!_running || _connection != null || _connecting) return;
    _retryTimer?.cancel();
    _attempt = 0;
    _connect();
  }

  Future<void> _connect() async {
    if (!_running || _connecting) return;
    _connecting = true;
    final generation = ++_generation;
    status.value = RealtimeStatus.connecting;
    try {
      final token = await _accessToken();
      if (token == null) throw StateError('no valid token');
      final connection = await _connector(
        url: url,
        token: token,
        onLost: () => _onLost(generation),
      );
      if (generation != _generation || !_running) {
        connection.close(); // stopped while we were connecting
        return;
      }
      _connection = connection;
      _connecting = false;
      _attempt = 0;
      for (final entry in _topics.entries) {
        _attach(entry.key, entry.value);
      }
      status.value = RealtimeStatus.connected;
      if (_hadConnection) _reconnected.add(null);
      _hadConnection = true;
    } catch (_) {
      if (generation != _generation) return;
      _connecting = false;
      _scheduleRetry();
    }
  }

  void _onLost(int generation) {
    if (generation != _generation) return; // an old connection
    _closeConnection();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_running) return;
    status.value = RealtimeStatus.connecting;
    _retryTimer?.cancel();
    _retryTimer = Timer(_backoff(_attempt++), _connect);
  }

  void _attach(String destination, _Topic topic) {
    final connection = _connection;
    if (connection == null || !topic.controller.hasListener) return;
    topic.detach();
    topic.stop = connection.subscribe(destination, (body) {
      final event = RealtimeEvent.tryParse(body);
      if (event != null && !topic.controller.isClosed) {
        topic.controller.add(event);
      }
    });
  }

  void _closeConnection() {
    for (final topic in _topics.values) {
      topic.stop = null; // the connection is going; nothing to unsubscribe
    }
    _connection?.close();
    _connection = null;
  }

  @visibleForTesting
  bool get isRunning => _running;
}

class _Topic {
  _Topic(this.controller);

  final StreamController<RealtimeEvent> controller;
  void Function()? stop;

  void detach() {
    stop?.call();
    stop = null;
  }
}
