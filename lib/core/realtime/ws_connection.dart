import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'realtime_connection.dart';

/// The real connector for the plain door `/realtime` (Track B, R5).
///
/// ```
/// open WebSocket ──► {"type":"auth","token":…}
///                ◄── {"type":"ready"}            → the Future completes ✅
///                ◄── {"type":"error",…} / closed → the Future fails ❌
/// then:  ──► subscribe / unsubscribe / send
///        ◄── {"type":"message","destination",…}  → that address's listener
///        ──► {"type":"ping"} every 10 s  ◄── {"type":"pong"}
///        nothing from the server for 25 s → LOST (a dead line)
/// ```
///
/// Like `connectStomp`: no reconnect here. `RealtimeService` reconnects, with
/// a FRESH token each try (13b Stages 2–3).
Future<RealtimeConnection> connectWebSocket({
  required String url,
  required String token,
  required void Function() onLost,
}) async {
  final channel = WebSocketChannel.connect(Uri.parse(url));
  await channel.ready.timeout(const Duration(seconds: 10));
  return WsLine.open(
    incoming: channel.stream,
    sendRaw: channel.sink.add,
    closeRaw: () => channel.sink.close(),
    token: token,
    onLost: onLost,
  );
}

/// The letters + timers of ONE line, without a real socket (testable: give
/// it a StreamController). [connectWebSocket] plugs a real WebSocket in.
class WsLine implements RealtimeConnection {
  WsLine._({
    required void Function(String) sendRaw,
    required Future<void> Function() closeRaw,
    required void Function() onLost,
  }) : _sendRaw = sendRaw,
       _closeRaw = closeRaw,
       _onLost = onLost;

  /// Sends `auth` and waits for `ready` (at most [readyTimeout]).
  static Future<WsLine> open({
    required Stream<dynamic> incoming,
    required void Function(String) sendRaw,
    required Future<void> Function() closeRaw,
    required String token,
    required void Function() onLost,
    Duration pingEvery = const Duration(seconds: 10),
    Duration deadAfter = const Duration(seconds: 25),
    Duration readyTimeout = const Duration(seconds: 10),
  }) {
    final line = WsLine._(sendRaw: sendRaw, closeRaw: closeRaw, onLost: onLost);
    line._start(incoming, token, pingEvery, deadAfter);
    return line._ready.future.timeout(
      readyTimeout,
      onTimeout: () {
        line._fail('no ready');
        return line._ready.future; // already completed with the error
      },
    );
  }

  final void Function(String) _sendRaw;
  final Future<void> Function() _closeRaw;
  final void Function() _onLost;

  final _ready = Completer<WsLine>();
  final Map<String, void Function(String?)> _listeners = {};
  StreamSubscription<dynamic>? _sub;
  Timer? _ping;
  Timer? _watchdog;
  bool _done = false; // closed by us, or lost (report once)

  void _start(
    Stream<dynamic> incoming,
    String token,
    Duration pingEvery,
    Duration deadAfter,
  ) {
    _sub = incoming.listen(
      (data) {
        // Any letter from the server = the line is alive.
        _watchdog?.cancel();
        _watchdog = Timer(deadAfter, () => _fail('silent'));
        _onLetter(data is String ? data : '', pingEvery);
      },
      onError: (Object e) => _fail(e),
      onDone: () => _fail('closed'),
      cancelOnError: true,
    );
    _watchdog = Timer(deadAfter, () => _fail('silent'));
    _write({'type': 'auth', 'token': token});
  }

  void _onLetter(String text, Duration pingEvery) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } catch (_) {
      return; // not our letter
    }
    if (json is! Map<String, dynamic>) return;
    switch (json['type']) {
      case 'ready':
        if (_ready.isCompleted) return;
        _ping = Timer.periodic(pingEvery, (_) => _write({'type': 'ping'}));
        _ready.complete(this);
      case 'message':
        final destination = json['destination'];
        // The same text has `event` + `payload` → RealtimeEvent.tryParse
        if (destination is String) _listeners[destination]?.call(text);
      case 'error':
        if (!_ready.isCompleted) {
          _fail(json['message'] ?? 'error'); // bad token → refused
        } else {
          debugPrint(
            '[realtime] server: ${json['message']} ${json['destination'] ?? ''}',
          );
        }
      default:
        break; // pong (the watchdog already reset)
    }
  }

  /// Before `ready`: the Future fails. After: [_onLost], once.
  void _fail(Object why) {
    if (_done) return;
    _done = true;
    _stopTimers();
    unawaited(_sub?.cancel());
    unawaited(_closeRaw().catchError((_) {}));
    if (!_ready.isCompleted) {
      _ready.completeError(StateError('realtime: $why'));
    } else {
      _onLost();
    }
  }

  @override
  void Function() subscribe(
    String destination,
    void Function(String? body) onMessage,
  ) {
    _listeners[destination] = onMessage;
    _write({'type': 'subscribe', 'destination': destination});
    return () {
      if (_listeners.remove(destination) != null) {
        _write({'type': 'unsubscribe', 'destination': destination});
      }
    };
  }

  @override
  void send(String destination, String body) {
    // [body] is already JSON text (RealtimeService encodes it)
    _write({
      'type': 'send',
      'destination': destination,
      'body': jsonDecode(body),
    });
  }

  @override
  void close() {
    if (_done) return;
    _done = true; // on purpose → never "lost"
    _stopTimers();
    unawaited(_sub?.cancel());
    unawaited(_closeRaw().catchError((_) {}));
  }

  void _write(Map<String, Object?> letter) {
    if (_done) return;
    try {
      _sendRaw(jsonEncode(letter));
    } catch (_) {
      // the socket died this very moment → onDone reports it
    }
  }

  void _stopTimers() {
    _ping?.cancel();
    _watchdog?.cancel();
  }
}
