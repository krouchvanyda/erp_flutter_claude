import 'dart:convert';

/// One message from the server over STOMP.
///
/// The backend wraps everything in `ChatEvent`:
/// `{ "event": "message.send", "payload": { …MessageDto… } }`.
/// This class knows only that envelope — never what a payload means (that's
/// the feature's job, e.g. `ChatRepository`).
class RealtimeEvent {
  const RealtimeEvent({required this.event, required this.payload});

  /// "message.send", "conversation.update", "call.invite", …
  final String event;

  /// The DTO as JSON (usually a Map).
  final Object? payload;

  /// A frame body → event. Not our envelope / not JSON → null (ignored).
  static RealtimeEvent? tryParse(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final event = json['event'];
      if (event is! String) return null;
      return RealtimeEvent(event: event, payload: json['payload']);
    } catch (_) {
      return null;
    }
  }

  /// The payload as a JSON object, or null.
  Map<String, dynamic>? get payloadMap =>
      payload is Map<String, dynamic> ? payload as Map<String, dynamic> : null;

  @override
  String toString() => 'RealtimeEvent($event)'; // no payload: private data
}
