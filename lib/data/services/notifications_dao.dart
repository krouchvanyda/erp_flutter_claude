import 'package:rxdart/rxdart.dart';

import 'package:erp_mobile/features/notifications/models/notification_model.dart' as domain;

/// In-memory notification inbox seeded with static demo data.
///
/// **Local persistence removed** — was a drift DAO; now a
/// process-lifetime in-memory store. Public API unchanged so
/// `NotificationsRepositoryImpl` + the inbox bloc + the AppBar badge
/// keep working. Reads are reactive via a [BehaviorSubject] (new
/// subscribers get the current snapshot immediately, like drift `.watch`).
class NotificationsDao {
  NotificationsDao() {
    for (final n in _seed()) {
      _store[n.id] = n;
    }
    _emit();
  }

  // id → notification (dismissed rows kept as tombstones, like the
  // old table).
  final Map<String, domain.AppNotification> _store =
      <String, domain.AppNotification>{};

  final BehaviorSubject<List<domain.AppNotification>> _inbox =
      BehaviorSubject<List<domain.AppNotification>>.seeded(
    const <domain.AppNotification>[],
  );

  /// Static seed inbox — a few representative entries so the inbox + the
  /// unread badge have content without a backend.
  static List<domain.AppNotification> _seed() {
    final now = DateTime.now().toUtc();
    return [
      domain.AppNotification(
        id: 'seed-welcome',
        title: 'Welcome to ERP',
        body: 'Your account is ready. Tap to explore.',
        category: 'system',
        receivedAt: now.subtract(const Duration(minutes: 2)),
      ),
      domain.AppNotification(
        id: 'seed-chat',
        title: 'New message',
        body: 'You have a new chat message.',
        category: 'chat',
        receivedAt: now.subtract(const Duration(hours: 1)),
      ),
      domain.AppNotification(
        id: 'seed-update',
        title: 'System update',
        body: 'A new app version is available.',
        category: 'system',
        receivedAt: now.subtract(const Duration(days: 1)),
        readAt: now.subtract(const Duration(hours: 12)),
      ),
    ];
  }

  /// Inbox snapshot — newest-first, dismissed rows excluded.
  List<domain.AppNotification> _snapshot() {
    final list = _store.values.where((n) => !n.dismissed).toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return List<domain.AppNotification>.unmodifiable(list);
  }

  void _emit() => _inbox.add(_snapshot());

  // ── Writes ───────────────────────────────────────────────────
  Future<void> upsert(domain.AppNotification n) async {
    _store[n.id] = n;
    _emit();
  }

  Future<void> upsertAll(Iterable<domain.AppNotification> all) async {
    for (final n in all) {
      _store[n.id] = n;
    }
    _emit();
  }

  Future<int> markRead(String id, {DateTime? now}) async {
    final n = _store[id];
    if (n == null || n.readAt != null) return 0;
    _store[id] = n.copyWith(readAt: now ?? DateTime.now().toUtc());
    _emit();
    return 1;
  }

  Future<int> markAllRead({DateTime? now}) async {
    final ts = now ?? DateTime.now().toUtc();
    var count = 0;
    for (final entry in _store.entries.toList()) {
      final n = entry.value;
      if (n.readAt == null && !n.dismissed) {
        _store[entry.key] = n.copyWith(readAt: ts);
        count++;
      }
    }
    if (count > 0) _emit();
    return count;
  }

  Future<int> dismiss(String id) async {
    final n = _store[id];
    if (n == null || n.dismissed) return 0;
    _store[id] = n.copyWith(dismissed: true);
    _emit();
    return 1;
  }

  Future<void> wipeAll() async {
    _store.clear();
    _emit();
  }

  // ── Reads ────────────────────────────────────────────────────
  Future<List<domain.AppNotification>> getInbox() async => _snapshot();

  Stream<List<domain.AppNotification>> watchInbox() => _inbox.stream;

  Stream<int> watchUnreadCount() => _inbox.stream
      .map((list) => list.where((n) => n.isUnread).length)
      .distinct();

  Future<void> dispose() async {
    await _inbox.close();
  }
}
