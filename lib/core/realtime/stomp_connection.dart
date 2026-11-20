import 'dart:async';

import 'package:stomp_dart_client/stomp_dart_client.dart';

/// One OPEN STOMP connection. Small on purpose, so tests can fake it.
abstract interface class StompConnection {
  /// Listen to [destination]. Returns a function that stops listening.
  void Function() subscribe(
    String destination,
    void Function(String? body) onMessage,
  );

  void close();
}

/// Opens ONE connection with [token]. Completes when STOMP says CONNECTED,
/// throws if it can't. [onLost] is called once if it drops LATER.
typedef StompConnector =
    Future<StompConnection> Function({
      required String url,
      required String token,
      required void Function() onLost,
    });

/// The real connector (`stomp_dart_client`).
///
/// - `reconnectDelay: Duration.zero` → the package does NOT reconnect by
///   itself. `RealtimeService` does it, so every try gets a FRESH token
///   (the package would reuse the old CONNECT headers).
/// - Heartbeats 10 s, like the server (`WebSocketConfig`): a dead socket is
///   noticed in ~20 s instead of hours.
Future<StompConnection> connectStomp({
  required String url,
  required String token,
  required void Function() onLost,
}) {
  final opened = Completer<StompConnection>();
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

class _StompClientConnection implements StompConnection {
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
  void close() => _client.deactivate();
}
