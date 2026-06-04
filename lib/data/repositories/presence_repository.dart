import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:erp_mobile/features/chat/models/presence_model.dart';
import 'package:erp_mobile/data/services/chats_remote_data_source.dart';

/// In-memory cache of every user's [Presence] state, fed by:
///   * `loadAll()` — bulk REST hydrate on boot + reconnect.
///   * `loadFor(ids)` — batch hydrate for the users currently on
///                       screen (group chat, chat info).
///   * `applyInboundPresence(...)` — live STOMP `presence.update`
///                                    frames pushed by
///                                    [bootChatTransport].
///
/// Backed by a [ValueNotifier]<int> revision counter so widgets can
/// subscribe via `AnimatedBuilder` / `ValueListenableBuilder` and
/// rebuild whenever any user's status changes without taking a
/// dependency on a heavyweight state-management lib.
class PresenceRepository {
  PresenceRepository({required this.remote});

  final ChatsRemoteDataSource remote;

  final Map<String, Presence> _byUserId = <String, Presence>{};

  /// Bumps every time the cache mutates. Widgets that render
  /// presence dots / "Online" subtitles listen via
  /// `AnimatedBuilder(animation: revision, builder: ...)` so a
  /// single STOMP frame fans out to every affected avatar in O(1)
  /// notifier work without us building a per-user stream.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Best-effort lookup. Returns an `offline / lastSeenAt: null`
  /// placeholder when the cache hasn't been populated yet for
  /// [userId] — the UI falls back to "no dot" which is harmless.
  Presence statusOf(String userId) =>
      _byUserId[userId] ?? Presence.offline(userId);

  /// Pull every tracked user from `GET /chats/presence`. Called
  /// from `bootChatTransport` on app boot + on every STOMP
  /// reconnect, and from `AppLifecycleState.resumed` so a phone
  /// returning from sleep doesn't keep stale dots.
  ///
  /// Failures (auth not ready, network down) are swallowed — the
  /// cache keeps whatever it had; the next call retries.
  Future<void> loadAll() async {
    try {
      final raws = await remote.listPresence();
      _putAll(raws);
    } catch (_) {/* swallow */}
  }

  /// Hydrate just [ids] — useful right after opening a group's
  /// chat info page to fill the dots without waiting for the
  /// global loadAll to round-trip (or repeat it for everyone).
  Future<void> loadFor(Iterable<String> ids) async {
    final intIds = <int>{};
    for (final id in ids) {
      final n = int.tryParse(id);
      if (n != null) intIds.add(n);
    }
    if (intIds.isEmpty) return;
    try {
      final raws = await remote.listPresenceForIds(intIds);
      _putAll(raws);
    } catch (_) {/* swallow */}
  }

  /// Apply a `/topic/presence` STOMP frame. Pushed in by
  /// `bootChatTransport` when a `PresenceUpdatedEvent` lands.
  void applyInboundPresence(Presence p) {
    _byUserId[p.userId] = p;
    revision.value++;
  }

  void _putAll(Iterable<dynamic> raws) {
    var changed = false;
    for (final raw in raws) {
      if (raw is! Map<String, dynamic>) continue;
      final p = Presence.fromJson(raw);
      _byUserId[p.userId] = p;
      changed = true;
    }
    if (changed) revision.value++;
  }
}
