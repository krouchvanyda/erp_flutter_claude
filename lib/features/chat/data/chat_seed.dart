import '../entities/call_log.dart';
import '../entities/chat_message.dart';
import '../entities/conversation.dart';

/// Demo data for Module 10 (Chat & Voice / Video).
///
/// Mirrors how the other modules seed their in-memory repos. Five
/// conversations (mix of direct + group), ~40 messages spread across
/// them, and a short call log with a mix of voice/video/missed entries.
class ChatSeed {
  /// Stable id of the signed-in demo user — pinned to the same
  /// `user-demo` used by Module 9 so the avatar / "You:" prefix line
  /// up with what the profile screen shows.
  static const String currentUserId = 'user-demo';
  static const String currentUserName = 'Demo Approver';

  static final List<ChatParticipantPreview> _peopleDirectory = [
    const ChatParticipantPreview(
      employeeId: 'emp-001',
      name: 'Demo Approver',
      presence: PresenceStatus.online,
    ),
    const ChatParticipantPreview(
      employeeId: 'emp-002',
      name: 'Sokha Tep',
      presence: PresenceStatus.online,
    ),
    const ChatParticipantPreview(
      employeeId: 'emp-003',
      name: 'Pisey Chan',
      presence: PresenceStatus.away,
    ),
    const ChatParticipantPreview(
      employeeId: 'emp-006',
      name: 'Vibol Sok',
      presence: PresenceStatus.online,
    ),
    const ChatParticipantPreview(
      employeeId: 'emp-007',
      name: 'Channary Pich',
      presence: PresenceStatus.online,
    ),
    const ChatParticipantPreview(
      employeeId: 'emp-008',
      name: 'Rithy Heng',
      presence: PresenceStatus.offline,
    ),
    const ChatParticipantPreview(
      employeeId: 'emp-009',
      name: 'Mealea Nuon',
      presence: PresenceStatus.online,
    ),
    const ChatParticipantPreview(
      employeeId: 'emp-010',
      name: 'Bopha Lim',
      presence: PresenceStatus.offline,
    ),
  ];

  static List<ChatParticipantPreview> get peopleDirectory =>
      List.unmodifiable(_peopleDirectory);

  static ChatParticipantPreview personById(String id) =>
      _peopleDirectory.firstWhere(
        (p) => p.employeeId == id,
        orElse: () => ChatParticipantPreview(employeeId: id, name: id),
      );

  static final List<ChatConversation> conversations = <ChatConversation>[
    ChatConversation(
      id: 'conv-001',
      name: 'Channary Pich',
      isGroup: false,
      isMuted: false,
      unreadCount: 2,
      createdAt: DateTime.utc(2026, 5, 10, 9),
      updatedAt: DateTime.utc(2026, 5, 20, 16, 32),
      lastMessageBody: 'Pushed the jitter helper on the retry-policy branch.',
      lastMessageSenderId: 'emp-007',
      lastMessageSenderName: 'Channary Pich',
      lastMessageAt: DateTime.utc(2026, 5, 20, 16, 32),
      presence: PresenceStatus.online,
      // Slice 10.2.7 — direct conversations carry the other person
      // here so the caller can build a targeted call.invite that
      // doesn't ring every connected client.
      participantPreviews: [_peopleDirectory[4]],
    ),
    ChatConversation(
      id: 'conv-002',
      name: 'ERP Mobile Core',
      isGroup: true,
      isMuted: false,
      unreadCount: 5,
      createdAt: DateTime.utc(2026, 4, 1),
      updatedAt: DateTime.utc(2026, 5, 21, 8, 45),
      lastMessageBody: 'Standup in 10 — agenda in the doc.',
      lastMessageSenderId: 'emp-002',
      lastMessageSenderName: 'Sokha Tep',
      lastMessageAt: DateTime.utc(2026, 5, 21, 8, 45),
      pinnedMessageId: 'msg-002-1',
      participantPreviews: [
        _peopleDirectory[1],
        _peopleDirectory[3],
        _peopleDirectory[4],
        _peopleDirectory[6],
      ],
      totalMembers: 6,
      onlineCount: 4,
    ),
    ChatConversation(
      id: 'conv-003',
      name: 'Vibol Sok',
      isGroup: false,
      isMuted: true,
      unreadCount: 0,
      createdAt: DateTime.utc(2026, 5, 14),
      updatedAt: DateTime.utc(2026, 5, 19, 14, 5),
      lastMessageBody: 'You: Sounds good — ship it Friday.',
      lastMessageSenderId: 'user-demo',
      lastMessageSenderName: 'Demo Approver',
      lastMessageAt: DateTime.utc(2026, 5, 19, 14, 5),
      presence: PresenceStatus.online,
      participantPreviews: [_peopleDirectory[3]],
    ),
    ChatConversation(
      id: 'conv-004',
      name: 'Warehouse RFID Pilot',
      isGroup: true,
      isMuted: false,
      unreadCount: 0,
      createdAt: DateTime.utc(2026, 5, 1),
      updatedAt: DateTime.utc(2026, 5, 18, 11, 22),
      lastMessageBody: '📎 floor-plan-v3.pdf',
      lastMessageType: 'file',
      lastMessageSenderId: 'emp-008',
      lastMessageSenderName: 'Rithy Heng',
      lastMessageAt: DateTime.utc(2026, 5, 18, 11, 22),
      participantPreviews: [
        _peopleDirectory[5],
        _peopleDirectory[4],
        _peopleDirectory[0],
      ],
      totalMembers: 3,
      onlineCount: 2,
    ),
    ChatConversation(
      id: 'conv-005',
      name: 'Pisey Chan',
      isGroup: false,
      isMuted: false,
      unreadCount: 0,
      createdAt: DateTime.utc(2026, 4, 28),
      updatedAt: DateTime.utc(2026, 5, 16, 18, 0),
      lastMessageBody: '🎤 Voice message · 0:23',
      lastMessageType: 'voice',
      lastMessageSenderId: 'emp-003',
      lastMessageSenderName: 'Pisey Chan',
      lastMessageAt: DateTime.utc(2026, 5, 16, 18, 0),
      presence: PresenceStatus.away,
      participantPreviews: [_peopleDirectory[2]],
    ),
    ChatConversation(
      id: 'conv-006',
      name: 'Mealea Nuon',
      isGroup: false,
      isMuted: false,
      unreadCount: 0,
      createdAt: DateTime.utc(2026, 5, 3),
      updatedAt: DateTime.utc(2026, 5, 12, 9, 30),
      lastMessageBody: '📷 Photo',
      lastMessageType: 'image',
      lastMessageSenderId: 'emp-009',
      lastMessageSenderName: 'Mealea Nuon',
      lastMessageAt: DateTime.utc(2026, 5, 12, 9, 30),
      presence: PresenceStatus.online,
      participantPreviews: [_peopleDirectory[6]],
    ),
  ];

  static final List<ChatMessage> messages = <ChatMessage>[
    // ── conv-001 (Channary direct) ──────────────────────────────
    ChatMessage(
      id: 'msg-001-1',
      conversationId: 'conv-001',
      senderId: 'user-demo',
      senderName: 'Demo Approver',
      type: ChatMessageType.text,
      body: 'Hey — did you get a chance to look at the retry policy spec?',
      sentAt: DateTime.utc(2026, 5, 20, 15, 10),
      deliveredAt: DateTime.utc(2026, 5, 20, 15, 10, 3),
      readAt: DateTime.utc(2026, 5, 20, 15, 22),
    ),
    ChatMessage(
      id: 'msg-001-2',
      conversationId: 'conv-001',
      senderId: 'emp-007',
      senderName: 'Channary Pich',
      type: ChatMessageType.text,
      body: 'Yes, just reviewed it. Cap at 5 retries with jitter, agreed.',
      sentAt: DateTime.utc(2026, 5, 20, 15, 24),
    ),
    ChatMessage(
      id: 'msg-001-3',
      conversationId: 'conv-001',
      senderId: 'emp-007',
      senderName: 'Channary Pich',
      type: ChatMessageType.text,
      body: 'One question — should we surface a retry-attempt counter to the UI or keep it silent?',
      sentAt: DateTime.utc(2026, 5, 20, 15, 25),
    ),
    ChatMessage(
      id: 'msg-001-4',
      conversationId: 'conv-001',
      senderId: 'user-demo',
      senderName: 'Demo Approver',
      type: ChatMessageType.text,
      body: 'Silent unless the final retry fails. Then a snackbar.',
      sentAt: DateTime.utc(2026, 5, 20, 15, 30),
      replyToId: 'msg-001-3',
      replyToSenderName: 'Channary Pich',
      replyToPreview:
          'One question — should we surface a retry-attempt counter…',
      deliveredAt: DateTime.utc(2026, 5, 20, 15, 30, 4),
      readAt: DateTime.utc(2026, 5, 20, 15, 32),
      reactions: const [
        ChatReaction(emoji: '👍', employeeIds: ['emp-007']),
      ],
    ),
    ChatMessage(
      id: 'msg-001-5',
      conversationId: 'conv-001',
      senderId: 'emp-007',
      senderName: 'Channary Pich',
      type: ChatMessageType.voice,
      voiceUrl: 'demo://voice/clip-1.m4a',
      voiceDurationSeconds: 42,
      sentAt: DateTime.utc(2026, 5, 20, 16, 28),
    ),
    ChatMessage(
      id: 'msg-001-6',
      conversationId: 'conv-001',
      senderId: 'emp-007',
      senderName: 'Channary Pich',
      type: ChatMessageType.text,
      body: 'Pushed the jitter helper on the retry-policy branch.',
      sentAt: DateTime.utc(2026, 5, 20, 16, 32),
    ),

    // ── conv-002 (ERP Mobile Core group) ────────────────────────
    ChatMessage(
      id: 'msg-002-1',
      conversationId: 'conv-002',
      senderId: 'emp-002',
      senderName: 'Sokha Tep',
      type: ChatMessageType.text,
      body:
          '📌 Standup notes live in /docs/standup.md — please add your asks before 9am.',
      sentAt: DateTime.utc(2026, 5, 19, 8, 30),
      isPinned: true,
    ),
    ChatMessage(
      id: 'msg-002-2',
      conversationId: 'conv-002',
      senderId: 'emp-006',
      senderName: 'Vibol Sok',
      type: ChatMessageType.text,
      body: 'Settings module skeleton is in review — feedback welcome.',
      sentAt: DateTime.utc(2026, 5, 20, 10, 15),
      reactions: const [
        ChatReaction(emoji: '🙏', employeeIds: ['emp-007', 'user-demo']),
        ChatReaction(emoji: '🚀', employeeIds: ['emp-002']),
      ],
    ),
    ChatMessage(
      id: 'msg-002-3',
      conversationId: 'conv-002',
      senderId: 'emp-007',
      senderName: 'Channary Pich',
      type: ChatMessageType.image,
      fileUrl: 'demo://image/board-screenshot.png',
      fileName: 'board-screenshot.png',
      fileSizeBytes: 184320,
      sentAt: DateTime.utc(2026, 5, 20, 14, 5),
    ),
    ChatMessage(
      id: 'msg-002-4',
      conversationId: 'conv-002',
      senderId: 'user-demo',
      senderName: 'Demo Approver',
      type: ChatMessageType.text,
      body: 'Looking good. Approve to merge when CI is green.',
      sentAt: DateTime.utc(2026, 5, 20, 14, 22),
      deliveredAt: DateTime.utc(2026, 5, 20, 14, 22, 3),
      readAt: DateTime.utc(2026, 5, 20, 16, 10),
    ),
    ChatMessage(
      id: 'msg-002-5',
      conversationId: 'conv-002',
      senderId: 'emp-009',
      senderName: 'Mealea Nuon',
      type: ChatMessageType.system,
      body: 'Mealea Nuon joined the group.',
      sentAt: DateTime.utc(2026, 5, 21, 7, 50),
    ),
    ChatMessage(
      id: 'msg-002-6',
      conversationId: 'conv-002',
      senderId: 'emp-002',
      senderName: 'Sokha Tep',
      type: ChatMessageType.text,
      body: 'Standup in 10 — agenda in the doc.',
      sentAt: DateTime.utc(2026, 5, 21, 8, 45),
    ),

    // ── conv-003 (Vibol direct, muted) ──────────────────────────
    ChatMessage(
      id: 'msg-003-1',
      conversationId: 'conv-003',
      senderId: 'emp-006',
      senderName: 'Vibol Sok',
      type: ChatMessageType.text,
      body: 'Trial-balance report rolled out fine — no rollbacks today.',
      sentAt: DateTime.utc(2026, 5, 19, 13, 50),
    ),
    ChatMessage(
      id: 'msg-003-2',
      conversationId: 'conv-003',
      senderId: 'user-demo',
      senderName: 'Demo Approver',
      type: ChatMessageType.text,
      body: 'Sounds good — ship it Friday.',
      sentAt: DateTime.utc(2026, 5, 19, 14, 5),
      deliveredAt: DateTime.utc(2026, 5, 19, 14, 5, 2),
      readAt: DateTime.utc(2026, 5, 19, 14, 7),
    ),

    // ── conv-004 (Warehouse RFID group) ─────────────────────────
    ChatMessage(
      id: 'msg-004-1',
      conversationId: 'conv-004',
      senderId: 'emp-008',
      senderName: 'Rithy Heng',
      type: ChatMessageType.text,
      body:
          'Walked Warehouse 1 today. 18 antenna positions tagged. Doc + scan in attachments.',
      sentAt: DateTime.utc(2026, 5, 18, 11, 18),
    ),
    ChatMessage(
      id: 'msg-004-2',
      conversationId: 'conv-004',
      senderId: 'emp-008',
      senderName: 'Rithy Heng',
      type: ChatMessageType.file,
      fileUrl: 'demo://file/floor-plan-v3.pdf',
      fileName: 'floor-plan-v3.pdf',
      fileSizeBytes: 2_412_345,
      sentAt: DateTime.utc(2026, 5, 18, 11, 22),
    ),

    // ── conv-005 (Pisey direct, voice last) ─────────────────────
    ChatMessage(
      id: 'msg-005-1',
      conversationId: 'conv-005',
      senderId: 'emp-003',
      senderName: 'Pisey Chan',
      type: ChatMessageType.text,
      body: 'Quick voice memo about the invoice approval flow:',
      sentAt: DateTime.utc(2026, 5, 16, 17, 55),
    ),
    ChatMessage(
      id: 'msg-005-2',
      conversationId: 'conv-005',
      senderId: 'emp-003',
      senderName: 'Pisey Chan',
      type: ChatMessageType.voice,
      voiceUrl: 'demo://voice/clip-2.m4a',
      voiceDurationSeconds: 23,
      sentAt: DateTime.utc(2026, 5, 16, 18, 0),
    ),

    // ── conv-006 (Mealea direct, image last) ────────────────────
    ChatMessage(
      id: 'msg-006-1',
      conversationId: 'conv-006',
      senderId: 'emp-009',
      senderName: 'Mealea Nuon',
      type: ChatMessageType.image,
      fileUrl: 'demo://image/mockup-preview.png',
      fileName: 'mockup-preview.png',
      fileSizeBytes: 312_456,
      sentAt: DateTime.utc(2026, 5, 12, 9, 30),
    ),
  ];

  static final List<ChatCallLog> callLog = <ChatCallLog>[
    ChatCallLog(
      id: 'call-001',
      conversationId: 'conv-001',
      callerId: 'emp-007',
      callerName: 'Channary Pich',
      callType: ChatCallType.voice,
      status: ChatCallStatus.answered,
      startedAt: DateTime.utc(2026, 5, 20, 11, 0),
      answeredAt: DateTime.utc(2026, 5, 20, 11, 0, 5),
      endedAt: DateTime.utc(2026, 5, 20, 11, 5, 23),
      durationSeconds: 5 * 60 + 23,
    ),
    ChatCallLog(
      id: 'call-002',
      conversationId: 'conv-003',
      callerId: 'emp-006',
      callerName: 'Vibol Sok',
      callType: ChatCallType.video,
      status: ChatCallStatus.answered,
      startedAt: DateTime.utc(2026, 5, 19, 16, 12),
      answeredAt: DateTime.utc(2026, 5, 19, 16, 12, 6),
      endedAt: DateTime.utc(2026, 5, 19, 16, 24, 16),
      durationSeconds: 12 * 60 + 4,
    ),
    ChatCallLog(
      id: 'call-003',
      conversationId: 'conv-005',
      callerId: 'emp-003',
      callerName: 'Pisey Chan',
      callType: ChatCallType.voice,
      status: ChatCallStatus.missed,
      startedAt: DateTime.utc(2026, 5, 18, 9, 22),
    ),
    ChatCallLog(
      id: 'call-004',
      conversationId: 'conv-006',
      callerId: 'user-demo',
      callerName: 'Demo Approver',
      callType: ChatCallType.video,
      status: ChatCallStatus.noAnswer,
      startedAt: DateTime.utc(2026, 5, 12, 9, 0),
    ),
  ];
}
