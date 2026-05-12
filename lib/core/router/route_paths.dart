/// Centralised route path & name registry.
///
/// Keeping these as compile-time constants (instead of magic strings sprinkled
/// across pages) gives us refactor safety and a single audit point for the URL
/// surface area. Names are used for `context.goNamed(...)` / `pushNamed(...)`;
/// paths are used for the URL.
abstract final class RoutePaths {
  // Bootstrap / shell ────────────────────────────────────────────
  static const splash = '/';
  static const splashName = 'splash';

  // Auth (Module 1) ──────────────────────────────────────────────
  static const login = '/login';
  static const loginName = 'login';

  // MFA (Phase 1.2) ──────────────────────────────────────────────
  /// OTP / TOTP entry — the multi-step auth flow lands here after the
  /// password step when the server reports an MFA challenge.
  static const otp = '/mfa/otp';
  static const otpName = 'otp';

  // Dashboard (Module 2) ─────────────────────────────────────────
  static const dashboard = '/dashboard';
  static const dashboardName = 'dashboard';

  // Catch-all ────────────────────────────────────────────────────
  static const notFoundName = 'notFound';

  /// Locations the router considers "public" — reachable without an
  /// authenticated [AuthSession]. The OTP page is included because the
  /// user is *mid-challenge* at that point (credentials submitted, no
  /// session token yet); the auth guard would otherwise bounce them to
  /// `/login` and lose the challenge context.
  static const publicLocations = <String>{splash, login, otp};
}
