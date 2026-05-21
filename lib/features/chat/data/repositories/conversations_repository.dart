import 'dart:async';

import '../../entities/conversation.dart';
import '../chat_seed.dart';

/// Slice 10.1.1 / 10.1.3 / 10.3.1 — in-memory conversations store.
///
/// Mirrors the contract a drift-backed `chat_conversations` repo will
/// expose: a watchAll stream, a per-id lookup, plus the
/// mute / delete / pin mutations the inbox + info pages need.
class ConversationsRepository {
  ConversationsRepository();

  static final List<ChatConversation> _seed =
      List<ChatConversation>.of(ChatSeed.conversations);

  final StreamController<List<ChatConversation>> _changes =
      StreamController<List<ChatConversation>>.broadcast();

  Future<List<ChatConversation>> getAll() async {
    final out = List<ChatConversation>.of(_seed)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(out);
  }

  Stream<List<ChatConversation>> watchAll() async* {
    yield await getAll();
    yield* _changes.stream;
  }

  Future<ChatConversation?> findById(String id) async {
    for (final c in _seed) {
      if (c.id == id) return c;
    }
    return null;
  }

  Stream<ChatConversation?> watchById(String id) async* {
    yield await findById(id);
    yield* _changes.stream.map((all) {
      for (final c in all) {
        if (c.id == id) return c;
      }
      return null;
    });
  }

  Future<ChatConversation> setMuted(String id, bool muted) async {
    return _mutate(id, (c) => c.copyWith(isMuted: muted));
  }

  Future<void> delete(String id) async {
    _seed.removeWhere((c) => c.id == id);
    await _emit();
  }

  Future<ChatConversation> markRead(String id) async {
    return _mutate(id, (c) => c.copyWith(unreadCount: 0));
  }

  Future<ChatConversation> bumpUnread(String id) async {
    return _mutate(id, (c) => c.copyWith(unreadCount: c.unreadCount + 1));
  }

  /// Inbound message arrived from the WebSocket — refresh the
  /// last-message fields + timestamp so the inbox preview updates.
  Future<ChatConversation> updateLastMessage({
    required String id,
    required String body,
    required String senderId,
    required String senderName,
    required DateTime at,
    String type = 'text',
  }) async {
    return _mutate(
      id,
      (c) => c.copyWith(
        lastMessageBody: body,
        lastMessageSenderId: senderId,
        lastMessageSenderName: senderName,
        lastMessageAt: at,
        lastMessageType: type,
        updatedAt: at,
      ),
    );
  }

  Future<ChatConversation> rename(String id, String name) async {
    return _mutate(id, (c) => c.copyWith(name: name));
  }

  Future<ChatConversation> setPinnedMessage(String id, String? messageId) async {
    return _mutate(
      id,
      (c) => c.copyWith(
        pinnedMessageId: messageId,
        clearPinnedMessage: messageId == null,
      ),
    );
  }

  /// Slice 10.1.3 — insert a brand new conversation.
  Future<ChatConversation> create(ChatConversation draft) async {
    final id = draft.id.isEmpty
        ? 'conv-${DateTime.now().microsecondsSinceEpoch}'
        : draft.id;
    final stamped = draft.copyWith(id: id);
    _seed.insert(0, stamped);
    await _emit();
    return stamped;
  }

  Future<ChatConversation> _mutate(
    String id,
    ChatConversation Function(ChatConversation) f,
  ) async {
    final idx = _seed.indexWhere((c) => c.id == id);
    if (idx == -1) {
      throw StateError('Conversation $id not found');
    }
    final next = f(_seed[idx]);
    _seed[idx] = next;
    await _emit();
    return next;
  }

  Future<void> _emit() async {
    if (!_changes.isClosed) _changes.add(await getAll());
  }
}
