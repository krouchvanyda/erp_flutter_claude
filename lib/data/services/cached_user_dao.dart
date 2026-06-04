import 'package:rxdart/rxdart.dart';

import 'package:erp_mobile/features/authentication/models/user_model.dart';

/// In-memory cache for the signed-in [User] and their permission set.
///
/// **Local persistence removed** — this used to be a drift (`SQLite`)
/// accessor. It is now a process-lifetime in-memory store seeded with a
/// static demo identity so the splash auto-login + dashboard + RBAC
/// route guards have data without any database. The public API is
/// unchanged, so [PermissionsSnapshot], `PermissionsRepository`,
/// `AuthRepository`, and `DioTokenRefresher` keep working as-is.
///
/// Reactive reads use [BehaviorSubject] so a new subscriber immediately
/// receives the latest value — matching the old drift `.watch()`
/// semantics the permission snapshot relies on.
class CachedUserDao {
  CachedUserDao() {
    // Seed a static demo identity so a cold start with valid tokens
    // (auto-login) lands on the dashboard with a name + permissions,
    // no network round-trip required.
    _profiles[_seedUser.id] = _seedUser;
    _permissions[_seedUser.id] = {..._seedRoles};
    _currentUserId = _seedUser.id;
    _emitCurrent();
  }

  /// Static seed identity. Mirrors the previous drift-seeded demo user.
  static const User _seedUser = User(
    id: 'user-demo',
    email: 'demo@erp.example',
    displayName: 'Demo Approver',
    roles: <String>{},
  );

  /// Static permission set granted to the seed user. `admin` surfaces the
  /// admin-demo tile; chat is ungated so it needs nothing.
  static const Set<String> _seedRoles = <String>{'admin'};

  // Profile (id → User without roles) + permissions kept separate so a
  // permission-only refresh doesn't touch the profile, matching the old
  // DAO's table split.
  final Map<String, User> _profiles = <String, User>{};
  final Map<String, Set<String>> _permissions = <String, Set<String>>{};
  String? _currentUserId;

  final BehaviorSubject<User?> _currentUser =
      BehaviorSubject<User?>.seeded(null);
  final Map<String, BehaviorSubject<Set<String>>> _permSubjects =
      <String, BehaviorSubject<Set<String>>>{};

  BehaviorSubject<Set<String>> _permSubjectFor(String userId) =>
      _permSubjects.putIfAbsent(
        userId,
        () => BehaviorSubject<Set<String>>.seeded(
          {...?_permissions[userId]},
        ),
      );

  void _emitCurrent() {
    _currentUser
        .add(_currentUserId == null ? null : _buildUser(_currentUserId!));
  }

  void _emitPerms(String userId) {
    final s = _permSubjects[userId];
    if (s != null) s.add({...?_permissions[userId]});
  }

  User? _buildUser(String userId) {
    final p = _profiles[userId];
    if (p == null) return null;
    return User(
      id: p.id,
      email: p.email,
      displayName: p.displayName,
      roles: {...?_permissions[userId]},
    );
  }

  // ── Writes ───────────────────────────────────────────────────
  Future<void> cacheUser(User user) async {
    _profiles[user.id] = User(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      roles: const <String>{},
    );
    _permissions[user.id] = {...user.roles};
    _currentUserId = user.id;
    _emitPerms(user.id);
    _emitCurrent();
  }

  Future<int> deleteUser(String userId) async {
    final existed = _profiles.remove(userId) != null;
    _permissions.remove(userId);
    if (_currentUserId == userId) _currentUserId = null;
    _emitPerms(userId);
    _emitCurrent();
    return existed ? 1 : 0;
  }

  Future<int> deletePermissions(String userId) async {
    final had = _permissions[userId]?.isNotEmpty ?? false;
    _permissions[userId] = <String>{};
    _emitPerms(userId);
    if (_currentUserId == userId) _emitCurrent();
    return had ? 1 : 0;
  }

  Future<void> replacePermissions(
    String userId,
    Set<String> permissions,
  ) async {
    _permissions[userId] = {...permissions};
    _emitPerms(userId);
    if (_currentUserId == userId) _emitCurrent();
  }

  Stream<Set<String>> watchPermissionsFor(String userId) =>
      _permSubjectFor(userId).stream;

  Future<void> wipeAll() async {
    final ids = {..._profiles.keys, ..._permissions.keys};
    _profiles.clear();
    _permissions.clear();
    _currentUserId = null;
    for (final id in ids) {
      _emitPerms(id);
    }
    _emitCurrent();
  }

  // ── Reads ────────────────────────────────────────────────────
  Future<User?> getUser(String userId) async => _buildUser(userId);

  Future<User?> getCurrentUser() async =>
      _currentUserId == null ? null : _buildUser(_currentUserId!);

  Stream<User?> watchCurrentUser() => _currentUser.stream;

  Future<Set<String>> getPermissions(String userId) async =>
      {...?_permissions[userId]};

  Future<bool> hasPermission(String userId, String permission) async =>
      _permissions[userId]?.contains(permission) ?? false;

  /// Release the reactive subjects. Production keeps this alive for the
  /// app's lifetime; provided for tests / hot-restart hygiene.
  Future<void> dispose() async {
    await _currentUser.close();
    for (final s in _permSubjects.values) {
      await s.close();
    }
    _permSubjects.clear();
  }
}
