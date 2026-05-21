import 'dart:async';

import '../../entities/chat_message.dart';
import '../chat_seed.dart';

/// Slice 10.1.2 / 10.1.4 — in-memory message store per conversation.
///
/// Backs the conversation page (paginated newest-first list) and the
/// message search page (full-text contains over `body`).
class MessagesRepository {
  MessagesRepository();

  static final List<ChatMessage> _seed =
      List<ChatMessage>.of(ChatSeed.messages);

  final StreamController<List<ChatMessage>> _changes =
      StreamController<List<ChatMessage>>.broadcast();

  Future<List<ChatMessage>> getForConversation(String conversationId) async {
    final out = _seed.where((m) => m.conversationId == conversationId).toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return List.unmodifiable(out);
  }

  Stream<List<ChatMessage>> watchForConversation(String conversationId) async* {
    yield await getForConversation(conversationId);
    yield* _changes.stream.map((all) {
      final out = all.where((m) => m.conversationId == conversationId).toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return List<ChatMessage>.unmodifiable(out);
    });
  }

  Future<List<ChatMessage>> getAll() async => List.unmodifiable(_seed);

  /// Slice 10.1.4 — naive in-memory full-text search. Real impl uses
  /// SQLite FTS5; the query surface here matches what we'd swap in.
  Future<List<ChatMessage>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const <ChatMessage>[];
    final out = <ChatMessage>[];
    for (final m in _seed) {
      if (m.isDeleted) continue;
      if (m.type == ChatMessageType.text && (m.body ?? '').toLowerCase().contains(q)) {
        out.add(m);
      } else if (m.type == ChatMessageType.file && (m.fileName ?? '').toLowerCase().contains(q)) {
        out.add(m);
      } else if (m.type == ChatMessageType.image && (m.fileName ?? '').toLowerCase().contains(q)) {
        out.add(m);
      }
    }
    out.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return List.unmodifiable(out);
  }

  Future<ChatMessage?> findById(String id) async {
    for (final m in _seed) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<ChatMessage> send(ChatMessage draft) async {
    final id = draft.id.isEmpty
        ? 'msg-${DateTime.now().microsecondsSinceEpoch}'
        : draft.id;
    final stamped = draft.copyWith(
      id: id,
      deliveredAt: DateTime.now(),
    );
    _seed.add(stamped);
    _emit();
    return stamped;
  }

  Future<ChatMessage> edit(String id, String newBody) async {
    return _mutate(id, (m) => m.copyWith(body: newBody, editedAt: DateTime.now()));
  }

  Future<ChatMessage> softDelete(String id) async {
    return _mutate(
      id,
      (m) => m.copyWith(
        isDeleted: true,
        body: 'Message deleted',
        reactions: const [],
      ),
    );
  }

  Future<ChatMessage> toggleReaction({
    required String messageId,
    required String emoji,
    required String employeeId,
  }) async {
    return _mutate(messageId, (m) {
      final next = m.reactions.map((r) => r.copyWith(employeeIds: List.of(r.employeeIds))).toList();
      final idx = next.indexWhere((r) => r.emoji == emoji);
      if (idx == -1) {
        next.add(ChatReaction(emoji: emoji, employeeIds: [employeeId]));
      } else {
        final ids = next[idx].employeeIds;
        if (ids.contains(employeeId)) {
          ids.remove(employeeId);
          if (ids.isEmpty) {
            next.removeAt(idx);
          } else {
            next[idx] = next[idx].copyWith(employeeIds: ids);
          }
        } else {
          ids.add(employeeId);
          next[idx] = next[idx].copyWith(employeeIds: ids);
        }
      }
      return m.copyWith(reactions: next);
    });
  }

  Future<ChatMessage> setPinned(String id, bool pinned) async {
    return _mutate(id, (m) => m.copyWith(isPinned: pinned));
  }

  Future<ChatMessage> _mutate(
    String id,
    ChatMessage Function(ChatMessage) f,
  ) async {
    final idx = _seed.indexWhere((m) => m.id == id);
    if (idx == -1) {
      throw StateError('Message $id not found');
    }
    final next = f(_seed[idx]);
    _seed[idx] = next;
    _emit();
    return next;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_seed));
  }
}
