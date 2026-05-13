import '../../domain/entities/permission.dart';
import '../../domain/repositories/permissions_repository.dart';
import '../datasources/cached_user_dao.dart';

/// Drift-backed [PermissionsRepository].
///
/// Maps `String ↔ Permission` at the boundary so the storage layer
/// stays string-keyed (matches what `user_permissions` already holds)
/// while the domain layer works with the typed [Permission] surface.
class PermissionsRepositoryImpl implements PermissionsRepository {
  PermissionsRepositoryImpl({required CachedUserDao cachedUserDao})
      : _dao = cachedUserDao;

  final CachedUserDao _dao;

  @override
  Future<Set<Permission>> getPermissions(String userId) async {
    final raw = await _dao.getPermissions(userId);
    return raw.map(Permission.parse).toSet();
  }

  @override
  Stream<Set<Permission>> watchPermissions(String userId) {
    return _dao
        .watchPermissionsFor(userId)
        .map((raw) => raw.map(Permission.parse).toSet());
  }

  @override
  Future<void> cachePermissions(
    String userId,
    Set<Permission> permissions,
  ) {
    return _dao.replacePermissions(
      userId,
      permissions.map((p) => p.token).toSet(),
    );
  }

  @override
  Future<bool> hasPermission(String userId, Permission required) async {
    final held = await getPermissions(userId);
    return held.grant(required);
  }
}
