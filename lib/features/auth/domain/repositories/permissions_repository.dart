import '../entities/permission.dart';

/// Domain contract for the per-user permission cache.
///
/// Wraps the raw `String`-keyed `user_permissions` table (Slice 1.1.2b)
/// in a typed [Permission] surface. The route guard (1.3.2) and the
/// `PermissionGuard` widget (1.3.3) are the primary consumers; the
/// auth feature's own refresh path uses [cachePermissions] when the
/// server returns a fresh role set.
abstract class PermissionsRepository {
  /// Snapshot of the [userId]'s held permissions. Empty set when no
  /// row is cached yet (treat as "no privileges").
  Future<Set<Permission>> getPermissions(String userId);

  /// Reactive variant — emits a fresh set whenever any
  /// `user_permissions` row for [userId] changes.
  Stream<Set<Permission>> watchPermissions(String userId);

  /// Atomically replaces the cached permissions for [userId]. Intended
  /// for the post-sign-in / post-RBAC-refresh path: server hands back
  /// the authoritative list, we replace ours wholesale.
  Future<void> cachePermissions(String userId, Set<Permission> permissions);

  /// Convenience predicate for ad-hoc checks. Implementations should
  /// honour the wildcard semantics from [Permission.grants].
  Future<bool> hasPermission(String userId, Permission required);
}
