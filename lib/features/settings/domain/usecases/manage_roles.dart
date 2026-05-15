import '../../../../core/error/failure.dart';
import '../entities/managed_user.dart';

/// Slice 9.2.2 — create a custom role from the editor.
Role createRole({
  required String name,
  required String description,
  required List<String> permissionTokens,
}) {
  final errors = <String, List<String>>{};
  if (name.trim().isEmpty) {
    errors.putIfAbsent('name', () => []).add('Required');
  }
  if (permissionTokens.isEmpty) {
    errors.putIfAbsent('permissionTokens', () => [])
        .add('Pick at least one scope');
  }
  if (errors.isNotEmpty) {
    throw ValidationFailure(fieldErrors: errors);
  }
  return Role(
    id: '', // assigned by repo
    name: name.trim(),
    description: description.trim(),
    permissionTokens: List.unmodifiable(permissionTokens),
  );
}

/// Slice 9.2.2 — replace the permission set on an existing role.
///
/// **Why the guard**: built-in roles (`admin`, `viewer`) are seeded by
/// the API. Letting the editor mutate them would create configuration
/// drift between the app and server snapshots. Mark them with
/// `isSystem: true` and refuse mutations here.
Role updateRolePermissions({
  required Role role,
  required List<String> permissionTokens,
}) {
  if (role.isSystem) {
    throw ConflictFailure(message: 'Built-in roles cannot be edited');
  }
  if (permissionTokens.isEmpty) {
    throw ValidationFailure(fieldErrors: {
      'permissionTokens': ['Pick at least one scope'],
    });
  }
  return role.copyWith(permissionTokens: List.unmodifiable(permissionTokens));
}

/// Slice 9.2.2 — guarded delete.
///
/// Two refusal cases:
/// - **System role**: same drift-prevention reason as above.
/// - **Role still in use**: prevents orphaning users whose only role
///   is about to vanish. Caller passes the current user list so the
///   check is online (no extra repo round-trip).
void ensureRoleIsDeletable({
  required Role role,
  required List<ManagedUser> currentUsers,
}) {
  if (role.isSystem) {
    throw ConflictFailure(message: 'Built-in roles cannot be deleted');
  }
  final inUse = currentUsers.any((u) => u.roleIds.contains(role.id));
  if (inUse) {
    throw ConflictFailure(
        message: 'Role is still assigned to one or more users');
  }
}
