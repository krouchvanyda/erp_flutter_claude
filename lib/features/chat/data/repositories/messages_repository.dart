import 'dart:async';

import '../../entities/chat_message.dart';
import '../chat_seed.dart';
import '../chat_transport.dart';

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

  /// Optional wire transport — when bound, [send] / [edit] / [softDelete]
  /// / [toggleReaction] publish their mutations to peers. Inbound peer
  /// events are routed via [applyInbound] which mutates local state
  /// without re-broadcasting (would cause an infinite loop).
  ChatTransport? _transport;

  void attachTransport(ChatTransport transport) {
    _transport = transport;
  }

  /// Called by the transport-listener bridge when an inbound event lands.
  /// Mutates local state WITHOUT publishing back — peers already know.
  Future<void> applyInbound(ChatTransportEvent event) async {
    switch (event) {
      case MessageReceivedEvent(message: final m):
        // De-dup by id in case a slow peer delivers something we
        // already have (e.g. echo from a buggy relay).
        if (_seed.any((existing) => existing.id == m.id)) return;
        _seed.add(m);
        _emit();
      case MessageEditedEvent(messageId: final id, newBody: final body):
        await _mutate(
          id,
          (m) => m.copyWith(body: body, editedAt: DateTime.now()),
          publish: false,
        );
      case MessageDeletedEvent(messageId: final id):
        await _mutate(
          id,
          (m) => m.copyWith(
            isDeleted: true,
            body: 'Message deleted',
            reactions: const [],
          ),
          publish: false,
        );
      case ReactionToggledEvent(
          messageId: final id,
          emoji: final emoji,
          employeeId: final empId
        ):
        await _toggleReactionLocal(id, emoji, empId);
      // Call signalling envelopes are routed through
      // CallSignalingService; the messages repo ignores them.
      case CallInviteEvent():
      case CallAcceptEvent():
      case CallRejectEvent():
      case CallHangupEvent():
        break;
    }
  }

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
    // Embed the sender id in the message id so two peers can't collide
    // on `msg-<microsec>` even if their clocks land in the same tick.
    final id = draft.id.isEmpty
        ? 'msg-${draft.senderId}-${DateTime.now().microsecondsSinceEpoch}'
        : draft.id;
    final stamped = draft.copyWith(
      id: id,
      deliveredAt: DateTime.now(),
    );
    _seed.add(stamped);
    _emit();
    _transport?.sendMessage(stamped);
    return stamped;
  }

  Future<ChatMessage> edit(String id, String newBody) async {
    final next = await _mutate(
      id,
      (m) => m.copyWith(body: newBody, editedAt: DateTime.now()),
      publish: false,
    );
    _transport?.sendEdit(id, newBody);
    return next;
  }

  Future<ChatMessage> softDelete(String id) async {
    final next = await _mutate(
      id,
      (m) => m.copyWith(
        isDeleted: true,
        body: 'Message deleted',
        reactions: const [],
      ),
      publish: false,
    );
    _transport?.sendDelete(id);
    return next;
  }

  Future<ChatMessage> toggleReaction({
    required String messageId,
    required String emoji,
    required String employeeId,
  }) async {
    final next = await _toggleReactionLocal(messageId, emoji, employeeId);
    _transport?.sendReaction(
      messageId: messageId,
      emoji: emoji,
      employeeId: employeeId,
    );
    return next;
  }

  Future<ChatMessage> _toggleReactionLocal(
    String messageId,
    String emoji,
    String employeeId,
  ) {
    return _mutate(
      messageId,
      (m) {
        final next = m.reactions
            .map((r) => r.copyWith(employeeIds: List.of(r.employeeIds)))
            .toList();
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
      },
      publish: false,
    );
  }

  Future<ChatMessage> setPinned(String id, bool pinned) async {
    return _mutate(id, (m) => m.copyWith(isPinned: pinned), publish: false);
  }

  Future<ChatMessage> _mutate(
    String id,
    ChatMessage Function(ChatMessage) f, {
    bool publish = false,
  }) async {
    final idx = _seed.indexWhere((m) => m.id == id);
    if (idx == -1) {
      throw StateError('Message $id not found');
    }
    final next = f(_seed[idx]);
    _seed[idx] = next;
    _emit();
    // `publish` is currently a no-op (each caller decides which wire
    // event to send, since mutations aren't 1:1 with wire messages).
    // The flag is kept on the signature so future callers can opt in
    // without rewiring every callsite.
    if (publish) {
      // intentionally empty — callers do their own _transport?.sendX()
    }
    return next;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_seed));
  }
}
