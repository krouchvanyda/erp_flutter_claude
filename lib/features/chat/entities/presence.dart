import 'conversation.dart';

/// Live presence snapshot for a single user, as returned by
/// `GET /api/v1/chats/presence*` and pushed via `/topic/presence`.
class Presence {
  const Presence({
    required this.userId,
    required this.status,
    this.lastSeenAt,
  });

  /// Stringified Long — matches how every other id in the chat module
  /// is carried (so look-ups can use the same `String` ids the rest
  /// of the codebase passes around).
  final String userId;
  final PresenceStatus status;

  /// Only populated when `status == offline`. Drives the "Last seen X
  /// minutes ago" subtitle on the direct-conversation header.
  final DateTime? lastSeenAt;

  /// Convenience for a missing-from-cache lookup — defaults to
  /// `offline` with no last-seen so the UI hides the dot gracefully.
  factory Presence.offline(String userId) =>
      Presence(userId: userId, status: PresenceStatus.offline);

  factory Presence.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] as String? ?? 'OFFLINE').toUpperCase();
    final status = switch (statusRaw) {
      'ONLINE' => PresenceStatus.online,
      'BUSY' => PresenceStatus.busy,
      'AWAY' => PresenceStatus.away,
      _ => PresenceStatus.offline,
    };
    final lastSeenRaw = json['lastSeenAt'];
    final lastSeen = lastSeenRaw is String && lastSeenRaw.isNotEmpty
        ? DateTime.tryParse(lastSeenRaw)
        : null;
    return Presence(
      userId: json['userId'].toString(),
      status: status,
      lastSeenAt: lastSeen,
    );
  }
}
