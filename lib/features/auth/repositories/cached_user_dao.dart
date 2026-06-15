import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

/// `SharedPreferences`-backed cache for the signed-in [User] and their
/// permission set.
///
/// Replaces the former drift table (the local SQLite database was removed).
/// Public API is unchanged so callers in the repository / route-guard layer
/// keep working: profile + permissions persist here; access/refresh tokens
/// never do (those stay in `flutter_secure_storage`).
///
/// Reactive reads ([watchCurrentUser] / [watchPermissionsFor]) emit the
/// current value on listen and re-emit whenever a write changes the store.
class CachedUserDao {
  CachedUserDao(this._prefs);

  final SharedPreferences _prefs;

  /// Fires after every write so the watch* generators re-read.
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static const String _kUserPrefix = 'auth.cached_user.';
  static const String _kPermsPrefix = 'auth.user_permissions.';
  static const String _kCurrentUserId = 'auth.current_user_id';

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  // ── Writes ───────────────────────────────────────────────────
  /// Replaces the cached profile **and** the permission set.
  Future<void> cacheUser(User user) async {
    await _prefs.setString(
      '$_kUserPrefix${user.id}',
      jsonEncode({
        'id': user.id,
        'email': user.email,
        'displayName': user.displayName,
      }),
    );
    await _prefs.setStringList(
      '$_kPermsPrefix${user.id}',
      user.roles.toList(growable: false),
    );
    await _prefs.setString(_kCurrentUserId, user.id);
    _emit();
  }

  /// Deletes the user and their permissions.
  Future<int> deleteUser(String userId) async {
    final existed = _prefs.containsKey('$_kUserPrefix$userId');
    await _prefs.remove('$_kUserPrefix$userId');
    await _prefs.remove('$_kPermsPrefix$userId');
    if (_prefs.getString(_kCurrentUserId) == userId) {
      await _prefs.remove(_kCurrentUserId);
    }
    _emit();
    return existed ? 1 : 0;
  }

  /// Removes every permission for [userId] without touching the profile.
  Future<int> deletePermissions(String userId) async {
    final existed = _prefs.containsKey('$_kPermsPrefix$userId');
    await _prefs.remove('$_kPermsPrefix$userId');
    _emit();
    return existed ? 1 : 0;
  }

  /// Atomically replaces the permission set for [userId].
  Future<void> replacePermissions(
    String userId,
    Set<String> permissions,
  ) async {
    await _prefs.setStringList(
      '$_kPermsPrefix$userId',
      permissions.toList(growable: false),
    );
    _emit();
  }

  /// Reactive variant of [getPermissions].
  Stream<Set<String>> watchPermissionsFor(String userId) async* {
    yield await getPermissions(userId);
    yield* _changes.stream.asyncMap((_) => getPermissions(userId));
  }

  /// Drops every cached user and every permission row.
  Future<void> wipeAll() async {
    final keys = _prefs.getKeys().where(
          (k) =>
              k.startsWith(_kUserPrefix) ||
              k.startsWith(_kPermsPrefix) ||
              k == _kCurrentUserId,
        );
    for (final k in keys.toList(growable: false)) {
      await _prefs.remove(k);
    }
    _emit();
  }

  // ── Reads ────────────────────────────────────────────────────
  /// Returns the [User] for [userId] (including permissions), or `null`.
  Future<User?> getUser(String userId) async {
    final raw = _prefs.getString('$_kUserPrefix$userId');
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return User(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      roles: await getPermissions(userId),
    );
  }

  /// Returns the most-recently-cached user — the splash probe uses this.
  Future<User?> getCurrentUser() async {
    final id = _prefs.getString(_kCurrentUserId);
    if (id == null) return null;
    return getUser(id);
  }

  /// Reactive variant for the route guard / dashboard avatar.
  Stream<User?> watchCurrentUser() async* {
    yield await getCurrentUser();
    yield* _changes.stream.asyncMap((_) => getCurrentUser());
  }

  Future<Set<String>> getPermissions(String userId) async {
    return (_prefs.getStringList('$_kPermsPrefix$userId') ?? const [])
        .toSet();
  }

  /// Single-permission probe for the route guard / `PermissionGuard`.
  Future<bool> hasPermission(String userId, String permission) async {
    return (await getPermissions(userId)).contains(permission);
  }
}
