/// Splash-time / login-time check for "is biometric login available on
/// this device for the most-recently-known user?".
///
/// **Why a probe and not a direct DAO read**: the page doesn't know
/// the user id at login time — they haven't signed in yet. The probe
/// hides the "look up the most recent cached user, then check their
/// biometric flag, then ask local_auth whether the device actually
/// supports biometric" chain behind one boolean.
abstract class BiometricAvailabilityProbe {
  Future<bool> isAvailable();
}
