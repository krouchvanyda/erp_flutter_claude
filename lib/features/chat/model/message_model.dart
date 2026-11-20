import 'package:collection/collection.dart';

import 'chat_enums.dart';
import 'reaction_model.dart';

/// One chat message (backend `MessageDto`).
///
/// A deleted message keeps its row but loses its content: the server sends
/// `deleted: true` and `body` / attachment = null.
class MessageModel {
  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.body,
    this.attachmentUrl,
    this.attachmentContentType,
    this.attachmentSizeBytes,
    this.durationSeconds,
    this.replyToMessageId,
    this.editedAt,
    this.deleted = false,
    this.reactions = const [],
    this.readByUserIds = const {},
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final String? body;
  final String? attachmentUrl; // "/uploads/..."
  final String? attachmentContentType;
  final int? attachmentSizeBytes;
  final int? durationSeconds; // VOICE
  final String? replyToMessageId;
  final DateTime? editedAt;
  final bool deleted;
  final List<ReactionModel> reactions;

  /// Members (not the sender) who have read this message.
  final Set<String> readByUserIds;
  final DateTime? createdAt; // local time

  /// Server ids are numbers sent as text: compare them as numbers
  /// ("9" < "10"). Used for "read up to id X".
  int get idNumber => int.tryParse(id) ?? 0;

  MessageModel copyWith({
    Set<String>? readByUserIds,
    List<ReactionModel>? reactions,
  }) => MessageModel(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    type: type,
    body: body,
    attachmentUrl: attachmentUrl,
    attachmentContentType: attachmentContentType,
    attachmentSizeBytes: attachmentSizeBytes,
    durationSeconds: durationSeconds,
    replyToMessageId: replyToMessageId,
    editedAt: editedAt,
    deleted: deleted,
    reactions: reactions ?? this.reactions,
    readByUserIds: readByUserIds ?? this.readByUserIds,
    createdAt: createdAt,
  );

  /// Short text for the inbox, WITHOUT "You: " — the tile adds that, in
  /// ONE place (CLAUDE.md).
  String get previewText {
    if (deleted) return 'Message deleted';
    return switch (type) {
      MessageType.image => '📷 Photo',
      MessageType.voice => '🎤 Voice message',
      MessageType.file => '📎 File',
      // the inbox tile asks ChatCallInfo for "📞 Missed voice call" (needs myId)
      MessageType.call => '📞 Call',
      MessageType.text => (body ?? '').trim(),
    };
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    id: '${json['id'] ?? ''}',
    conversationId: '${json['conversationId'] ?? ''}',
    senderId: '${json['senderId'] ?? ''}',
    type: MessageType.fromJson(json['type']),
    body: json['body'] as String?,
    attachmentUrl: json['attachmentUrl'] as String?,
    attachmentContentType: json['attachmentContentType'] as String?,
    attachmentSizeBytes: (json['attachmentSizeBytes'] as num?)?.toInt(),
    durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    replyToMessageId: json['replyToMessageId'] == null
        ? null
        : '${json['replyToMessageId']}',
    editedAt: _time(json['editedAt']),
    deleted: json['deleted'] as bool? ?? false,
    reactions: [
      for (final r in json['reactions'] as List? ?? const [])
        ReactionModel.fromJson(r as Map<String, dynamic>),
    ],
    readByUserIds: {
      for (final id in json['readByUserIds'] as List? ?? const []) '$id',
    },
    createdAt: _time(json['createdAt']),
  );

  /// Server `Instant` ("2026-11-20T03:15:00Z", UTC) → local time.
  static DateTime? _time(Object? value) =>
      DateTime.tryParse(value as String? ?? '')?.toLocal();

  static const _reactionsEq = ListEquality<ReactionModel>();
  static const _idsEq = SetEquality<String>();

  @override
  bool operator ==(Object other) =>
      other is MessageModel &&
      other.id == id &&
      other.conversationId == conversationId &&
      other.senderId == senderId &&
      other.type == type &&
      other.body == body &&
      other.attachmentUrl == attachmentUrl &&
      other.attachmentContentType == attachmentContentType &&
      other.attachmentSizeBytes == attachmentSizeBytes &&
      other.durationSeconds == durationSeconds &&
      other.replyToMessageId == replyToMessageId &&
      other.editedAt == editedAt &&
      other.deleted == deleted &&
      _reactionsEq.equals(other.reactions, reactions) &&
      _idsEq.equals(other.readByUserIds, readByUserIds) &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    senderId,
    type,
    body,
    attachmentUrl,
    attachmentContentType,
    attachmentSizeBytes,
    durationSeconds,
    replyToMessageId,
    editedAt,
    deleted,
    _reactionsEq.hash(reactions),
    _idsEq.hash(readByUserIds),
    createdAt,
  );

  /// No message text in logs (private).
  @override
  String toString() => 'MessageModel($id, ${type.name})';
}
