import 'dart:async';

import '../../entities/conversation.dart';
import '../chat_dto_mappers.dart';
import '../chat_seed.dart';
import '../chats_remote_data_source.dart';
import '../users_cache.dart';

/// Slice 10.1.1 / 10.1.3 / 10.3.1 — conversations store.
///
/// Backed by an in-memory list seeded from [ChatSeed] for the
/// pre-backend demo era. Once [setRemote] has been called by
/// `bootChatTransport`, [loadInbox] replaces that seed with real
/// `GET /api/v1/chats/conversations` rows mapped via
/// [conversationFromDto]. The seed remains as a fallback so the demo
/// keeps running if the backend isn't reachable.
///
/// Exposes a `watchAll` stream, per-id lookup, and the
/// mute / delete / pin / rename / avatar mutations the inbox + info
/// pages need.
class ConversationsRepository {
  ConversationsRepository() {
    // When UsersCache fills in late (e.g. the picker opened AFTER the
    // inbox already rendered with raw ids), re-resolve every cached
    // conversation's participant names + last-sender name in place and
    // re-emit so the inbox tiles refresh. The repo is a process-life
    // singleton, so we don't bother holding the subscription.
    UsersCache.instance.changes.listen((_) => _reresolveNames());
  }

  static final List<ChatConversation> _seed =
      List<ChatConversation>.of(ChatSeed.conversations);

  final StreamController<List<ChatConversation>> _changes =
      StreamController<List<ChatConversation>>.broadcast();

  /// Walk the in-memory list and patch any name fields that the
  /// [UsersCache] can now resolve. No-op if nothing changes.
  void _reresolveNames() {
    var anyChanged = false;
    for (var i = 0; i < _seed.length; i++) {
      final c = _seed[i];

      // Patch each participant preview if a fresher name is cached.
      var previewsChanged = false;
      final nextPreviews = <ChatParticipantPreview>[];
      for (final p in c.participantPreviews) {
        final cachedName = UsersCache.instance.nameOf(p.employeeId);
        if (cachedName != null && cachedName != p.name) {
          nextPreviews.add(ChatParticipantPreview(
            employeeId: p.employeeId,
            name: cachedName,
            avatarUrl:
                UsersCache.instance.avatarOf(p.employeeId) ?? p.avatarUrl,
            presence: p.presence,
          ));
          previewsChanged = true;
        } else {
          nextPreviews.add(p);
        }
      }

      // Direct conversations show the OTHER participant's name as the
      // conversation title — keep that in sync with the cache.
      String? nextName;
      if (!c.isGroup && nextPreviews.isNotEmpty) {
        final cached = UsersCache.instance.nameOf(nextPreviews.first.employeeId);
        if (cached != null && cached != c.name) nextName = cached;
      }

      // Last-message sender name for the inbox preview row.
      String? nextLastSenderName;
      if (c.lastMessageSenderId != null) {
        final cached = UsersCache.instance.nameOf(c.lastMessageSenderId!);
        if (cached != null && cached != c.lastMessageSenderName) {
          nextLastSenderName = cached;
        }
      }

      if (previewsChanged || nextName != null || nextLastSenderName != null) {
        _seed[i] = c.copyWith(
          name: nextName ?? c.name,
          participantPreviews: previewsChanged ? nextPreviews : null,
          lastMessageSenderName:
              nextLastSenderName ?? c.lastMessageSenderName,
        );
        anyChanged = true;
      }
    }
    if (anyChanged) _emit();
  }

  /// Real-backend data source. Bound by `bootChatTransport` once
  /// settings are loaded so we know which user id to compute display
  /// names against. Null = pre-Prompt-2 demo mode.
  ChatsRemoteDataSource? _remote;
  String? _currentUserId;

  void setRemote(
    ChatsRemoteDataSource remote, {
    required String currentUserId,
  }) {
    _remote = remote;
    _currentUserId = currentUserId;
  }

  /// Prompt 2 — pull the inbox from `GET /chats/conversations` and
  /// replace the in-memory cache with the result.
  ///
  /// Each row goes through [conversationFromDto] so the page layer
  /// keeps reading the same [ChatConversation] shape it always has —
  /// no widget changes needed. The response envelope from
  /// `ChatsRemoteDataSource.listConversations` is the unwrapped `data`
  /// payload: `{items: [...], page, pageSize, total}`.
  ///
  /// No-op when [setRemote] hasn't been called yet (demo mode).
  /// Errors are swallowed so a flaky backend doesn't take the UI down
  /// — the seed stays in place and the next call retries.
  Future<void> loadInbox({int page = 1, int pageSize = 50}) async {
    final remote = _remote;
    final userId = _currentUserId;
    if (remote == null || userId == null) return;
    try {
      final body = await remote.listConversations(page: page, pageSize: pageSize);
      final items = body['items'];
      if (items is! List) return;
      final next = <ChatConversation>[];
      for (final raw in items) {
        if (raw is Map<String, dynamic>) {
          next.add(conversationFromDto(raw, currentUserId: userId));
        }
      }
      _seed
        ..clear()
        ..addAll(next);
      await _emit();
    } catch (_) {
      // Backend down or auth not ready — keep whatever cache we had.
    }
  }

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

  /// Slice 10.1.8 — return the local direct conversation whose other
  /// participant is [employeeId], or null if no such conv exists.
  ///
  /// Used by `bootChatTransport` to redirect inbound direct messages
  /// to the right local conv on the receiver's device. Without this,
  /// a message Vibol sends in HIS conv-005 ("Pisey direct" on Vibol's
  /// seed) would land in Pisey's conv-005 — which is *her* own
  /// self-direct seed slot, not her chat with Vibol. By looking up
  /// "my direct conv whose other participant is `senderId`" we land
  /// the message in Pisey's conv-003 ("Vibol Sok") instead.
  Future<ChatConversation?> findDirectWith(String employeeId) async {
    for (final c in _seed) {
      if (c.isGroup) continue;
      for (final p in c.participantPreviews) {
        if (p.employeeId == employeeId) return c;
      }
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

  /// Slice 10.3.3 — admin set the group photo from a local file
  /// (typically the `image_picker` result). Pass `null` to clear.
  Future<ChatConversation> setAvatarPath(String id, String? path) async {
    return _mutate(
      id,
      (c) => c.copyWith(
        avatarFilePath: path,
        clearAvatarFilePath: path == null,
      ),
    );
  }

  /// Slice 10.3.2 — admin adds new members to an existing group.
  ///
  /// De-duplicates against current `participantPreviews` so re-adding
  /// someone is a no-op. Updates `totalMembers` + `onlineCount`
  /// accordingly so the AppBar subtitle stays in sync.
  Future<ChatConversation> addMembers({
    required String id,
    required List<ChatParticipantPreview> people,
  }) async {
    if (people.isEmpty) return (await findById(id))!;
    return _mutate(id, (c) {
      final existing = {for (final p in c.participantPreviews) p.employeeId};
      final additions =
          people.where((p) => !existing.contains(p.employeeId)).toList();
      if (additions.isEmpty) return c;
      final nextPreviews =
          List<ChatParticipantPreview>.of(c.participantPreviews)
            ..addAll(additions);
      final addedOnline = additions
          .where((p) => p.presence == PresenceStatus.online)
          .length;
      return c.copyWith(
        participantPreviews: nextPreviews,
        totalMembers: c.totalMembers + additions.length,
        onlineCount: c.onlineCount + addedOnline,
        updatedAt: DateTime.now(),
      );
    });
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
