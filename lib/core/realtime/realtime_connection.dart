/// ONE open live connection: the "remote control" with 3 buttons
/// (13b Stage 2). Small on purpose, so tests can fake it.
///
/// Two real ones exist (Track B, branch `feature/raw-websocket`):
/// - `connectWebSocket` (ws_connection.dart): our JSON letters on the plain
///   door `/realtime` — the one the app uses.
/// - `connectStomp` (stomp_connection.dart): STOMP on `/ws` — the old door,
///   kept until Track B is finished.
abstract interface class RealtimeConnection {
  /// Listen to [destination]. [onMessage] gets the letter's JSON text (it has
  /// `event` + `payload`, read by `RealtimeEvent.tryParse`). Returns a
  /// function that stops listening.
  void Function() subscribe(
    String destination,
    void Function(String? body) onMessage,
  );

  /// SEND [body] (JSON text) to [destination] (e.g. "/app/conversations/42/typing").
  void send(String destination, String body);

  /// Hang up on purpose (logout / stop). Never reported as "lost".
  void close();
}

/// Opens ONE connection with [token]. Completes when the server says "you're
/// in", throws if it can't. [onLost] is called once if it drops LATER.
typedef RealtimeConnector =
    Future<RealtimeConnection> Function({
      required String url,
      required String token,
      required void Function() onLost,
    });
