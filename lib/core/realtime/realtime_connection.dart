/// ONE open live connection: the "remote control" with 3 buttons
/// (13b Stage 2). Small on purpose, so tests can fake it.
///
/// The real one is `connectWebSocket` (ws_connection.dart): our JSON letters
/// on the plain door `/realtime` (Track B). The old STOMP connector was
/// removed after R6; to see it: `git show feature/rebuild:lib/core/realtime/stomp_connection.dart`.
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
