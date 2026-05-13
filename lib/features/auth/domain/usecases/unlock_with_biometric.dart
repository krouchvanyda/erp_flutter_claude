import '../../data/datasources/biometric_service.dart';
import '../../data/datasources/biometric_settings_dao.dart';
import '../../data/datasources/cached_user_dao.dart';

/// "Try to unlock with the biometric the user previously enrolled."
///
/// Composes three checks before prompting the OS:
/// 1. **A cached user exists** — biometric unlock is a per-user
///    preference; with no cached user there's nothing to gate.
/// 2. **`biometric_on` is `true` for that user** — read straight from
///    drift via [BiometricSettingsDao]; the flag is the single source
///    of truth (per CLAUDE.md Slice 1.2.3 storage rule).
/// 3. **The OS reports the hardware is currently usable** — enrolled
///    fingerprint/face exists and isn't lockout-blocked.
///
/// Only when all three hold does the use case actually call
/// [BiometricService.authenticate]. Otherwise it returns
/// [BiometricUnlockResult.unavailable] so the caller can fall through
/// to the PIN / password flow.
class UnlockWithBiometricUseCase {
  const UnlockWithBiometricUseCase({
    required CachedUserDao cachedUserDao,
    required BiometricSettingsDao settingsDao,
    required BiometricService biometricService,
  })  : _cachedUserDao = cachedUserDao,
        _settingsDao = settingsDao,
        _biometricService = biometricService;

  final CachedUserDao _cachedUserDao;
  final BiometricSettingsDao _settingsDao;
  final BiometricService _biometricService;

  Future<BiometricUnlockResult> call({required String reason}) async {
    final user = await _cachedUserDao.getCurrentUser();
    if (user == null) return BiometricUnlockResult.unavailable;

    final enabled = await _settingsDao.isEnabledFor(user.id);
    if (!enabled) return BiometricUnlockResult.unavailable;

    final hardwareOk = await _biometricService.isAvailable();
    if (!hardwareOk) return BiometricUnlockResult.unavailable;

    return _biometricService.authenticate(reason: reason);
  }
}
