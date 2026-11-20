/// ONLINE (app open), BUSY (in a call), OFFLINE (closed / minimized).
enum PresenceStatus {
  online,
  busy,
  offline;

  static PresenceStatus fromJson(Object? value) => switch (value) {
    'ONLINE' => online,
    'BUSY' => busy,
    _ => offline, // unknown → the safe answer
  };
}

/// Someone's online status (backend `PresenceDto`).
class PresenceModel {
  const PresenceModel({
    required this.userId,
    required this.status,
    this.lastSeenAt,
  });

  final String userId;
  final PresenceStatus status;

  /// When they went OFFLINE (local time); null while online / busy.
  final DateTime? lastSeenAt;

  bool get isOnline => status != PresenceStatus.offline;

  factory PresenceModel.fromJson(Map<String, dynamic> json) => PresenceModel(
    userId: '${json['userId'] ?? ''}',
    status: PresenceStatus.fromJson(json['status']),
    lastSeenAt: DateTime.tryParse(
      json['lastSeenAt'] as String? ?? '',
    )?.toLocal(),
  );

  @override
  bool operator ==(Object other) =>
      other is PresenceModel &&
      other.userId == userId &&
      other.status == status &&
      other.lastSeenAt == lastSeenAt;

  @override
  int get hashCode => Object.hash(userId, status, lastSeenAt);

  @override
  String toString() => 'PresenceModel($userId, ${status.name})';
}
