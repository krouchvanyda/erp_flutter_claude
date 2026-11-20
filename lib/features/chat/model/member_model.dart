import 'chat_enums.dart';

/// One person in a conversation (backend `MemberDto`).
///
/// The server already puts the member's name + avatar here, so the app never
/// needs a separate `/users/{id}` lookup to draw a chat.
class MemberModel {
  const MemberModel({
    required this.userId,
    this.fullName,
    this.avatarUrl,
    this.role = MemberRole.member,
    this.muted = false,
    this.lastReadMessageId,
  });

  final String userId;
  final String? fullName; // null if the user row is gone
  final String? avatarUrl;
  final MemberRole role;
  final bool muted;

  /// The newest message this member has read (read receipts, Step 5.6).
  final String? lastReadMessageId;

  /// Never an empty name on screen.
  String get displayName {
    final name = fullName?.trim() ?? '';
    return name.isEmpty ? 'User #$userId' : name;
  }

  factory MemberModel.fromJson(Map<String, dynamic> json) => MemberModel(
    userId: '${json['userId'] ?? ''}',
    fullName: json['fullName'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    role: MemberRole.fromJson(json['role']),
    muted: json['muted'] as bool? ?? false,
    lastReadMessageId: json['lastReadMessageId'] == null
        ? null
        : '${json['lastReadMessageId']}',
  );

  @override
  bool operator ==(Object other) =>
      other is MemberModel &&
      other.userId == userId &&
      other.fullName == fullName &&
      other.avatarUrl == avatarUrl &&
      other.role == role &&
      other.muted == muted &&
      other.lastReadMessageId == lastReadMessageId;

  @override
  int get hashCode =>
      Object.hash(userId, fullName, avatarUrl, role, muted, lastReadMessageId);

  @override
  String toString() => 'MemberModel($userId)';
}
