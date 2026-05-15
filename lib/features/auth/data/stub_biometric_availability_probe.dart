import '../domain/biometric_availability.dart';

/// Demo probe for the Screen 1.1 BiometricLoginButton.
///
/// Returns the constant passed at construction so the demo can flip
/// the button on/off without touching drift. Real impl (Slice 1.2.3)
/// will read `cached_user.id` → `BiometricSettingsDao.isEnabledFor` →
/// `LocalAuthBiometricService.isAvailable` and return the AND of the
/// two.
class StubBiometricAvailabilityProbe implements BiometricAvailabilityProbe {
  const StubBiometricAvailabilityProbe({this.available = false});

  final bool available;

  @override
  Future<bool> isAvailable() async => available;
}
