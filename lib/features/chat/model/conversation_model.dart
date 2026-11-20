import 'package:collection/collection.dart';

import 'chat_enums.dart';
import 'member_model.dart';
import 'message_model.dart';

/// One inbox row (backend `ConversationDto`).
///
/// A DIRECT chat has no name of its own: we show the OTHER person. That's why
/// [title], [avatarUrlFor] and [otherMember] need MY id.
class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    this.members = const [],
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.createdAt,
  });

  final String id;
  final ConversationType type;
  final String? name; // GROUP name; null for DIRECT
  final String? avatarUrl; // GROUP avatar
  final List<MemberModel> members;
  final MessageModel? lastMessage;
  final DateTime? lastMessageAt; // local time
  final int unreadCount;
  final DateTime? createdAt;

  bool get isGroup => type == ConversationType.group;

  /// DIRECT: the person who is not me. (null for groups)
  MemberModel? otherMember(String? myId) {
    if (isGroup) return null;
    return members.firstWhereOrNull((m) => m.userId != myId) ??
        members.firstOrNull; // a chat with myself
  }

  /// What the inbox shows as the row's name.
  String title(String? myId) {
    if (isGroup) {
      final n = name?.trim() ?? '';
      return n.isEmpty ? 'Group' : n;
    }
    return otherMember(myId)?.displayName ?? 'Chat';
  }

  /// The row's photo: group avatar, or the other person's avatar.
  String? avatarUrlFor(String? myId) =>
      isGroup ? avatarUrl : otherMember(myId)?.avatarUrl;

  /// "Dara" — who sent [lastMessage], for "Dara: 📷 Photo" in groups.
  String? lastSenderName() {
    final senderId = lastMessage?.senderId;
    return members.firstWhereOrNull((m) => m.userId == senderId)?.displayName;
  }

  /// Sort key: newest activity first.
  DateTime get activityAt =>
      lastMessageAt ??
      createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0); // never null

  factory ConversationModel.fromJson(
    Map<String, dynamic> json,
  ) => ConversationModel(
    id: '${json['id'] ?? ''}',
    type: ConversationType.fromJson(json['type']),
    name: json['name'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    members: [
      for (final m in json['members'] as List? ?? const [])
        MemberModel.fromJson(m as Map<String, dynamic>),
    ],
    lastMessage: json['lastMessage'] == null
        ? null
        : MessageModel.fromJson(json['lastMessage'] as Map<String, dynamic>),
    lastMessageAt: DateTime.tryParse(
      json['lastMessageAt'] as String? ?? '',
    )?.toLocal(),
    unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
  );

  static const _membersEq = ListEquality<MemberModel>();

  @override
  bool operator ==(Object other) =>
      other is ConversationModel &&
      other.id == id &&
      other.type == type &&
      other.name == name &&
      other.avatarUrl == avatarUrl &&
      _membersEq.equals(other.members, members) &&
      other.lastMessage == lastMessage &&
      other.lastMessageAt == lastMessageAt &&
      other.unreadCount == unreadCount &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    avatarUrl,
    _membersEq.hash(members),
    lastMessage,
    lastMessageAt,
    unreadCount,
    createdAt,
  );

  @override
  String toString() => 'ConversationModel($id, ${type.name})';
}
