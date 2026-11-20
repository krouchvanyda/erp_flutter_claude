import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/router/auth_session.dart';
import '../model/presence_model.dart';
import 'chat_repository.dart';

/// Who is online — for the people the app is showing (5.6).
///
/// ```
/// watch([2, 5])  ──► GET /chats/presence?ids=2&ids=5 (only ids not known yet)
/// /topic/presence ──► presence.update → change one person
/// reconnected     ──► GET again for everyone watched (we missed updates)
/// logout          ──► forget everything
/// widgets: ValueListenableBuilder(presence) → 🟢 dot, "online", "last seen"
/// ```
///
/// One store for the app (like `RealtimeService.status`): the inbox and an
/// open chat show the SAME person, so they share one answer.
class PresenceStore {
  PresenceStore(this._repository, {required AuthSession session})
    : _session = session {
    _session.addListener(_onSession);
  }

  final ChatRepository _repository;
  final AuthSession _session;

  final ValueNotifier<Map<String, PresenceModel>> presence = ValueNotifier(
    const {},
  );

  final Set<String> _watched = {};
  StreamSubscription<PresenceModel>? _live;
  StreamSubscription<void>? _reconnected;

  PresenceModel? of(String userId) => presence.value[userId];

  /// Start following [userIds] (new ones are loaded in ONE request).
  Future<void> watch(Iterable<String> userIds) async {
    _listen();
    final missing = {
      for (final id in userIds)
        if (id.isNotEmpty && !_watched.contains(id)) id,
    };
    if (missing.isEmpty) return;
    _watched.addAll(missing);
    await _load(missing);
  }

  void _listen() {
    _live ??= _repository.presenceUpdates().listen((p) {
      if (_watched.contains(p.userId)) _merge([p]);
    });
    _reconnected ??= _repository.reconnected.listen((_) {
      if (_watched.isNotEmpty) _load(_watched.toSet());
    });
  }

  Future<void> _load(Set<String> ids) async {
    final result = await _repository.loadPresence(ids);
    result.fold((_) {}, _merge); // offline → no dots; the next load fixes it
  }

  void _merge(List<PresenceModel> list) {
    if (list.isEmpty) return;
    presence.value = {...presence.value, for (final p in list) p.userId: p};
  }

  void _onSession() {
    if (_session.isAuthenticated) return;
    // logged out → the next user must not see this one's contacts
    _live?.cancel();
    _reconnected?.cancel();
    _live = null;
    _reconnected = null;
    _watched.clear();
    presence.value = const {};
  }
}
