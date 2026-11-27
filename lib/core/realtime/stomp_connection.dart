import 'dart:async';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'realtime_connection.dart';

// The remote control (RealtimeConnection) + its connector type now live in
// realtime_connection.dart (Track B). This file is the OLD door (STOMP on
// /ws), kept until Track B is finished; the app uses ws_connection.dart.

/// The real connector (`stomp_dart_client`).
///
/// - `reconnectDelay: Duration.zero` → the package does NOT reconnect by
///   itself. `RealtimeService` does it, so every try gets a FRESH token
///   (the package would reuse the old CONNECT headers).
/// - Heartbeats 10 s, like the server (`WebSocketConfig`): a dead socket is
///   noticed in ~20 s instead of hours.
Future<RealtimeConnection> connectStomp({
  required String url,
  required String token,
  required void Function() onLost,
}) {
  final opened = Completer<RealtimeConnection>();
  late final StompClient client;
  var lost = false;

  void fail(Object error) {
    if (!opened.isCompleted) {
      opened.completeError(error);
      client.deactivate();
    } else if (!lost) {
      lost = true;
      onLost();
    }
  }

  client = StompClient(
    config: StompConfig(
      url: url,
      reconnectDelay: Duration.zero,
      connectionTimeout: const Duration(seconds: 10),
      heartbeatIncoming: const Duration(seconds: 10),
      heartbeatOutgoing: const Duration(seconds: 10),
      stompConnectHeaders: {'Authorization': 'Bearer $token'},
      onConnect: (_) {
        if (!opened.isCompleted) {
          opened.complete(_StompClientConnection(client));
        }
      },
      onStompError: (frame) => fail(StateError('STOMP error')),
      onWebSocketError: (dynamic error) => fail(error ?? 'socket error'),
      onWebSocketDone: () => fail(StateError('socket closed')),
      onDisconnect: (_) => fail(StateError('disconnected')),
    ),
  )..activate();
  return opened.future;
}

class _StompClientConnection implements RealtimeConnection {
  _StompClientConnection(this._client);

  final StompClient _client;

  @override
  void Function() subscribe(
    String destination,
    void Function(String? body) onMessage,
  ) {
    final unsubscribe = _client.subscribe(
      destination: destination,
      callback: (frame) => onMessage(frame.body),
    );
    return () {
      try {
        unsubscribe();
      } catch (_) {
        // already closed — nothing to undo
      }
    };
  }

  @override
  void send(String destination, String body) =>
      _client.send(destination: destination, body: body);

  @override
  void close() => _client.deactivate();
}
