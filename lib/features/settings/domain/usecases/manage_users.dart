import '../../../../core/error/failure.dart';
import '../entities/managed_user.dart';

/// Slice 9.2.1 — admin invites a new user.
///
/// Pure-Dart validation only — the repo persists the resulting record.
/// New users always start in `ManagedUserStatus.invited`; status flips
/// to `active` when they sign in for the first time (real impl wires
/// that to the auth session — out of scope for this slice).
ManagedUser inviteUser({
  required String email,
  required String name,
  required List<String> roleIds,
  required DateTime now,
}) {
  final errors = <String, List<String>>{};
  if (!_emailLooksValid(email)) {
    errors.putIfAbsent('email', () => []).add('Looks invalid');
  }
  if (name.trim().isEmpty) {
    errors.putIfAbsent('name', () => []).add('Required');
  }
  if (roleIds.isEmpty) {
    errors.putIfAbsent('roleIds', () => []).add('Pick at least one role');
  }
  if (errors.isNotEmpty) {
    throw ValidationFailure(fieldErrors: errors);
  }
  return ManagedUser(
    id: '', // assigned by repo
    email: email.trim().toLowerCase(),
    name: name.trim(),
    status: ManagedUserStatus.invited,
    roleIds: List.unmodifiable(roleIds),
    createdAt: now,
  );
}

/// Slice 9.2.1 — guarded suspend / reactivate.
///
/// The "self-suspend" guard is the safety rail: an admin must not be
/// able to lock themselves out of the admin console mid-edit. The
/// caller passes `currentUserId` so we can compare.
ManagedUser setUserStatus({
  required ManagedUser user,
  required ManagedUserStatus newStatus,
  required String currentUserId,
}) {
  if (user.id == currentUserId &&
      newStatus == ManagedUserStatus.suspended) {
    throw ConflictFailure(message: 'You cannot suspend your own account');
  }
  if (user.status == newStatus) return user;
  return user.copyWith(status: newStatus);
}

/// Slice 9.2.1 — assign / unassign roles. Same self-lock guard:
/// stripping every role from the current user would lock them out.
ManagedUser updateUserRoles({
  required ManagedUser user,
  required List<String> roleIds,
  required String currentUserId,
}) {
  if (user.id == currentUserId && roleIds.isEmpty) {
    throw ConflictFailure(
        message: 'You cannot remove every role from your own account');
  }
  return user.copyWith(roleIds: List.unmodifiable(roleIds));
}

bool _emailLooksValid(String email) {
  // Intentionally permissive — full RFC 5322 is the API's job. We just
  // catch obvious typos.
  final trimmed = email.trim();
  if (trimmed.isEmpty) return false;
  final at = trimmed.indexOf('@');
  if (at <= 0 || at == trimmed.length - 1) return false;
  if (trimmed.contains(' ')) return false;
  if (!trimmed.substring(at).contains('.')) return false;
  return true;
}
