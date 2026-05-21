/// Online / away / offline state shown as a small dot on the avatar.
enum PresenceStatus { online, away, offline }

/// Slice 10.1.1 — direct or group conversation summary.
///
/// Mirrors the `chat_conversations` table shape (id, name, avatar_url,
/// is_group, is_muted, last_message_*, unread_count, created/updated_at).
/// Group conversations stash an extra `participantPreviews` field that
/// the inbox uses to render the 3-avatar cluster without joining on
/// the full participants table for every row.
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.isMuted,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    this.lastMessageBody,
    this.lastMessageSenderId,
    this.lastMessageSenderName,
    this.lastMessageAt,
    this.lastMessageType = 'text',
    this.presence = PresenceStatus.offline,
    this.pinnedMessageId,
    this.participantPreviews = const <ChatParticipantPreview>[],
    this.onlineCount = 0,
    this.totalMembers = 0,
  });

  final String id;
  final String name;
  final bool isGroup;
  final bool isMuted;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? avatarUrl;
  final String? lastMessageBody;
  final String? lastMessageSenderId;
  final String? lastMessageSenderName;
  final DateTime? lastMessageAt;

  /// Type of the last message — text / voice / image / file / system.
  /// Drives the prefix icon + label on the inbox preview row.
  final String lastMessageType;

  /// Online presence for direct conversations. Group conversations
  /// surface [onlineCount] instead.
  final PresenceStatus presence;

  /// Id of the pinned message, if any. Conversation page uses this to
  /// render the pinned-message banner.
  final String? pinnedMessageId;

  /// Lightweight previews for the avatar cluster on group rows.
  final List<ChatParticipantPreview> participantPreviews;

  /// Group-only counters surfaced in the AppBar subtitle of the
  /// conversation page ("X members · Y online").
  final int onlineCount;
  final int totalMembers;

  ChatConversation copyWith({
    String? id,
    String? name,
    bool? isGroup,
    bool? isMuted,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? avatarUrl,
    String? lastMessageBody,
    String? lastMessageSenderId,
    String? lastMessageSenderName,
    DateTime? lastMessageAt,
    String? lastMessageType,
    PresenceStatus? presence,
    String? pinnedMessageId,
    bool clearPinnedMessage = false,
    List<ChatParticipantPreview>? participantPreviews,
    int? onlineCount,
    int? totalMembers,
  }) =>
      ChatConversation(
        id: id ?? this.id,
        name: name ?? this.name,
        isGroup: isGroup ?? this.isGroup,
        isMuted: isMuted ?? this.isMuted,
        unreadCount: unreadCount ?? this.unreadCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        lastMessageBody: lastMessageBody ?? this.lastMessageBody,
        lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
        lastMessageSenderName:
            lastMessageSenderName ?? this.lastMessageSenderName,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        lastMessageType: lastMessageType ?? this.lastMessageType,
        presence: presence ?? this.presence,
        pinnedMessageId: clearPinnedMessage
            ? null
            : (pinnedMessageId ?? this.pinnedMessageId),
        participantPreviews: participantPreviews ?? this.participantPreviews,
        onlineCount: onlineCount ?? this.onlineCount,
        totalMembers: totalMembers ?? this.totalMembers,
      );
}

/// Inbox-only mini-projection of a participant — just what's needed to
/// render the avatar cluster (no roles, no timestamps).
class ChatParticipantPreview {
  const ChatParticipantPreview({
    required this.employeeId,
    required this.name,
    this.avatarUrl,
    this.presence = PresenceStatus.offline,
  });

  final String employeeId;
  final String name;
  final String? avatarUrl;
  final PresenceStatus presence;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isEmpty ? '?' : parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Slice 10.1.3 — full participant record (group admin flags, join
/// timestamp, last-read).
class ChatParticipant {
  const ChatParticipant({
    required this.conversationId,
    required this.employeeId,
    required this.name,
    required this.isAdmin,
    required this.joinedAt,
    this.avatarUrl,
    this.role,
    this.lastReadAt,
    this.presence = PresenceStatus.offline,
  });

  final String conversationId;
  final String employeeId;
  final String name;
  final bool isAdmin;
  final DateTime joinedAt;
  final String? avatarUrl;
  final String? role;
  final DateTime? lastReadAt;
  final PresenceStatus presence;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isEmpty ? '?' : parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  ChatParticipant copyWith({
    String? conversationId,
    String? employeeId,
    String? name,
    bool? isAdmin,
    DateTime? joinedAt,
    String? avatarUrl,
    String? role,
    DateTime? lastReadAt,
    PresenceStatus? presence,
  }) =>
      ChatParticipant(
        conversationId: conversationId ?? this.conversationId,
        employeeId: employeeId ?? this.employeeId,
        name: name ?? this.name,
        isAdmin: isAdmin ?? this.isAdmin,
        joinedAt: joinedAt ?? this.joinedAt,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role ?? this.role,
        lastReadAt: lastReadAt ?? this.lastReadAt,
        presence: presence ?? this.presence,
      );
}
