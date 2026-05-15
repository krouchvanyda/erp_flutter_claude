import '../../../../core/error/failure.dart';
import '../entities/app_lock_settings.dart';

/// Slice 9.3.3 — PIN format validation.
///
/// **Why a constant rule, not a regex flag**: simpler to reason about
/// and easier to test. 4–8 digits matches the iOS / Android system
/// expectation and keeps the keypad on numeric mode.
void validatePinFormat(String pin) {
  if (pin.length < 4 || pin.length > 8) {
    throw ValidationFailure(fieldErrors: {
      'pin': ['Must be 4–8 digits'],
    });
  }
  for (var i = 0; i < pin.length; i++) {
    final code = pin.codeUnitAt(i);
    if (code < 0x30 || code > 0x39) {
      throw ValidationFailure(fieldErrors: {
        'pin': ['Digits only'],
      });
    }
  }
}

/// Slice 9.3.3 — confirm-PIN flow checks the two entries match before
/// the secret hits storage.
void ensurePinConfirmationMatches({
  required String pin,
  required String confirm,
}) {
  if (pin != confirm) {
    throw ValidationFailure(fieldErrors: {
      'confirm': ['PINs do not match'],
    });
  }
}

/// Slice 9.3.3 — auto-lock window validation.
///
/// 0 means "lock immediately on resume"; the upper cap of 60 minutes
/// matches what most banking apps allow before forcing re-auth.
AppLockSettings setAutoLockMinutes({
  required AppLockSettings current,
  required int minutes,
}) {
  if (minutes < 0 || minutes > 60) {
    throw ValidationFailure(fieldErrors: {
      'autoLockMinutes': ['Must be between 0 and 60 minutes'],
    });
  }
  return current.copyWith(autoLockMinutes: minutes);
}

/// Slice 9.3.3 — disabling PIN auto-disables biometric (biometric is
/// the unlock mechanism for the PIN — without a PIN, biometric has
/// nothing to prove).
AppLockSettings setPinEnabled({
  required AppLockSettings current,
  required bool enabled,
}) {
  if (!enabled) {
    return current.copyWith(pinEnabled: false, biometricEnabled: false);
  }
  return current.copyWith(pinEnabled: true);
}

/// Slice 9.3.3 — biometric requires PIN to be set first.
AppLockSettings setBiometricEnabled({
  required AppLockSettings current,
  required bool enabled,
}) {
  if (enabled && !current.pinEnabled) {
    throw ConflictFailure(message: 'Set up a PIN before enabling biometric');
  }
  return current.copyWith(biometricEnabled: enabled);
}
