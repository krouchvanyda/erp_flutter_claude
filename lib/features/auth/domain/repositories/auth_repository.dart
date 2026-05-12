/// Auth-feature repository surface. Lives in `domain/` and imports
/// **nothing** from `dio` / `drift` / `flutter_secure_storage` — those
/// are the implementation's problem.
///
/// Slice 1.1.4 ships only the sign-out contract; subsequent slices
/// (1.1.1 login form, 1.2.x SSO, 1.3.x RBAC) extend this interface as
/// the use cases for those flows are wired up.
abstract class AuthRepository {
  /// Server-revoke the refresh token (best-effort) and wipe every local
  /// trace of the session — secure-storage tokens **and** drift-cached
  /// profile + permissions.
  ///
  /// Returns successfully even if the server-side revoke fails: the
  /// local cleanup must not depend on network reachability or the user
  /// could end up unable to sign out.
  Future<void> signOut();
}
