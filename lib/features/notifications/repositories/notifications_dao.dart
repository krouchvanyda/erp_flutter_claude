import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification.dart' as domain;

/// `SharedPreferences`-backed DAO for the notification inbox (Slice 2.3.1).
///
/// Replaces the former drift table (local SQLite removed). The whole inbox
/// is persisted as one JSON blob — fine for the modest notification volume.
/// Public API is unchanged so [NotificationsRepositoryImpl] keeps working.
class NotificationsDao {
  NotificationsDao(this._prefs);

  final SharedPreferences _prefs;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static const String _kKey = 'notifications.inbox.v1';

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  List<domain.AppNotification> _readAll() {
    final raw = _prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => _fromJson(e as Map<String, dynamic>))
        .toList(growable: true);
  }

  Future<void> _writeAll(List<domain.AppNotification> all) async {
    await _prefs.setString(
      _kKey,
      jsonEncode(all.map(_toJson).toList(growable: false)),
    );
    _emit();
  }

  // ── Writes ───────────────────────────────────────────────────
  Future<void> upsert(domain.AppNotification n) async {
    final all = _readAll()..removeWhere((e) => e.id == n.id);
    all.add(n);
    await _writeAll(all);
  }

  Future<void> upsertAll(Iterable<domain.AppNotification> incoming) async {
    final all = _readAll();
    for (final n in incoming) {
      all.removeWhere((e) => e.id == n.id);
      all.add(n);
    }
    await _writeAll(all);
  }

  Future<int> markRead(String id, {DateTime? now}) async {
    final all = _readAll();
    var touched = 0;
    for (var i = 0; i < all.length; i++) {
      if (all[i].id == id && all[i].readAt == null) {
        all[i] = all[i].copyWith(readAt: now ?? DateTime.now().toUtc());
        touched++;
      }
    }
    if (touched > 0) await _writeAll(all);
    return touched;
  }

  Future<int> markAllRead({DateTime? now}) async {
    final all = _readAll();
    var touched = 0;
    for (var i = 0; i < all.length; i++) {
      if (all[i].readAt == null && !all[i].dismissed) {
        all[i] = all[i].copyWith(readAt: now ?? DateTime.now().toUtc());
        touched++;
      }
    }
    if (touched > 0) await _writeAll(all);
    return touched;
  }

  Future<int> dismiss(String id) async {
    final all = _readAll();
    var touched = 0;
    for (var i = 0; i < all.length; i++) {
      if (all[i].id == id && !all[i].dismissed) {
        all[i] = all[i].copyWith(dismissed: true);
        touched++;
      }
    }
    if (touched > 0) await _writeAll(all);
    return touched;
  }

  Future<void> wipeAll() async {
    await _prefs.remove(_kKey);
    _emit();
  }

  // ── Reads ────────────────────────────────────────────────────
  List<domain.AppNotification> _inbox() {
    final all = _readAll().where((n) => !n.dismissed).toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return all;
  }

  Future<List<domain.AppNotification>> getInbox() async => _inbox();

  Stream<List<domain.AppNotification>> watchInbox() async* {
    yield _inbox();
    yield* _changes.stream.map((_) => _inbox());
  }

  Stream<int> watchUnreadCount() async* {
    int unread() =>
        _readAll().where((n) => n.readAt == null && !n.dismissed).length;
    yield unread();
    yield* _changes.stream.map((_) => unread());
  }

  // ── Mapping ──────────────────────────────────────────────────
  static Map<String, dynamic> _toJson(domain.AppNotification n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'category': n.category,
        'routeName': n.routeName,
        'pathParameters': n.pathParameters,
        'receivedAt': n.receivedAt.toIso8601String(),
        'readAt': n.readAt?.toIso8601String(),
        'dismissed': n.dismissed,
      };

  static domain.AppNotification _fromJson(Map<String, dynamic> j) =>
      domain.AppNotification(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        category: j['category'] as String,
        routeName: j['routeName'] as String?,
        pathParameters: (j['pathParameters'] as Map?)
                ?.map((k, v) => MapEntry(k as String, v as String)) ??
            const <String, String>{},
        receivedAt: DateTime.parse(j['receivedAt'] as String),
        readAt: j['readAt'] == null
            ? null
            : DateTime.parse(j['readAt'] as String),
        dismissed: j['dismissed'] as bool? ?? false,
      );
}
