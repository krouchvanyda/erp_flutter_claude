import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/settings/domain/entities/app_lock_settings.dart';
import 'package:erp_mobile/features/settings/domain/usecases/manage_app_lock.dart';
import 'package:test/test.dart';

void main() {
  group('validatePinFormat', () {
    test('accepts 4–8 digits', () {
      validatePinFormat('1234');
      validatePinFormat('12345678');
    });

    test('rejects too short', () {
      expect(() => validatePinFormat('123'),
          throwsA(isA<ValidationFailure>()));
    });

    test('rejects too long', () {
      expect(() => validatePinFormat('123456789'),
          throwsA(isA<ValidationFailure>()));
    });

    test('rejects non-digits', () {
      expect(() => validatePinFormat('12ab'),
          throwsA(isA<ValidationFailure>()));
    });
  });

  group('ensurePinConfirmationMatches', () {
    test('passes when pins match', () {
      ensurePinConfirmationMatches(pin: '1234', confirm: '1234');
    });

    test('throws when pins differ', () {
      expect(
        () =>
            ensurePinConfirmationMatches(pin: '1234', confirm: '5678'),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('setAutoLockMinutes', () {
    final base = AppLockSettings.initial;

    test('accepts 0 (immediate)', () {
      final out = setAutoLockMinutes(current: base, minutes: 0);
      expect(out.autoLockMinutes, 0);
    });

    test('accepts 60 (max)', () {
      final out = setAutoLockMinutes(current: base, minutes: 60);
      expect(out.autoLockMinutes, 60);
    });

    test('rejects negative', () {
      expect(
        () => setAutoLockMinutes(current: base, minutes: -1),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects >60', () {
      expect(
        () => setAutoLockMinutes(current: base, minutes: 61),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('setPinEnabled', () {
    test('disabling PIN also disables biometric', () {
      const enabled = AppLockSettings(
        pinEnabled: true,
        biometricEnabled: true,
        autoLockMinutes: 5,
      );
      final out = setPinEnabled(current: enabled, enabled: false);
      expect(out.pinEnabled, isFalse);
      expect(out.biometricEnabled, isFalse);
    });

    test('enabling PIN preserves biometric setting', () {
      const noLock = AppLockSettings(
        pinEnabled: false,
        biometricEnabled: false,
        autoLockMinutes: 5,
      );
      final out = setPinEnabled(current: noLock, enabled: true);
      expect(out.pinEnabled, isTrue);
      expect(out.biometricEnabled, isFalse);
    });
  });

  group('setBiometricEnabled', () {
    test('refuses to enable biometric without PIN', () {
      expect(
        () => setBiometricEnabled(
          current: AppLockSettings.initial,
          enabled: true,
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('enables when PIN is set', () {
      const withPin = AppLockSettings(
        pinEnabled: true,
        biometricEnabled: false,
        autoLockMinutes: 5,
      );
      final out = setBiometricEnabled(current: withPin, enabled: true);
      expect(out.biometricEnabled, isTrue);
    });

    test('always allows disabling', () {
      const withBoth = AppLockSettings(
        pinEnabled: true,
        biometricEnabled: true,
        autoLockMinutes: 5,
      );
      final out = setBiometricEnabled(current: withBoth, enabled: false);
      expect(out.biometricEnabled, isFalse);
    });
  });
}
