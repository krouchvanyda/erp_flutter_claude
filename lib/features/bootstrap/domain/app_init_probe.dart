/// Outcome of the splash-time probe (Screen 0.1).
///
/// Closed enum so the [AppInitBloc] handler stays exhaustive — adding
/// a new redirect target (e.g. forced password reset) means a compile
/// error here, not a silent fallthrough.
enum AppInitOutcome {
  /// No token in secure storage → route to `/login`.
  unauthenticated,

  /// Token + cached user present, no lock policy active → `/dashboard`.
  authenticated,

  /// Token present BUT the device-local lock policy is engaged
  /// (PIN + autoLockMinutes elapsed since backgrounding, or biometric
  /// preferred for resume) → `/lock`.
  locked,
}

/// Splash-time probe contract.
///
/// **Why an interface, not a static call**: the bloc unit tests a fake
/// probe to drive each branch deterministically, while production wires
/// in a probe that reads `flutter_secure_storage` + drift `cached_user`.
/// The bloc itself stays storage-agnostic.
abstract class AppInitProbe {
  Future<AppInitOutcome> run();
}
