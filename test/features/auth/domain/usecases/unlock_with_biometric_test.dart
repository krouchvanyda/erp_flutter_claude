import 'package:drift/native.dart';
import 'package:erp_mobile/core/database/app_database.dart';
import 'package:erp_mobile/features/auth/data/datasources/biometric_service.dart';
import 'package:erp_mobile/features/auth/data/datasources/biometric_settings_dao.dart';
import 'package:erp_mobile/features/auth/data/datasources/cached_user_dao.dart';
import 'package:erp_mobile/features/auth/domain/entities/user.dart';
import 'package:erp_mobile/features/auth/domain/usecases/unlock_with_biometric.dart';
import 'package:test/test.dart';

const _alice = User(
  id: 'u-1',
  email: 'alice@example.com',
  displayName: 'Alice',
);

class _ScriptedBiometricService implements BiometricService {
  _ScriptedBiometricService({
    required this.available,
    required this.result,
  });

  bool available;
  BiometricUnlockResult result;
  int isAvailableCalls = 0;
  int authenticateCalls = 0;
  String? lastReason;

  @override
  Future<bool> isAvailable() async {
    isAvailableCalls++;
    return available;
  }

  @override
  Future<BiometricUnlockResult> authenticate({required String reason}) async {
    authenticateCalls++;
    lastReason = reason;
    return result;
  }
}

({
  UnlockWithBiometricUseCase useCase,
  AppDatabase db,
  BiometricSettingsDao settings,
  CachedUserDao users,
  _ScriptedBiometricService service,
}) _build({
  bool available = true,
  BiometricUnlockResult result = BiometricUnlockResult.succeeded,
}) {
  final db = AppDatabase(NativeDatabase.memory());
  final service = _ScriptedBiometricService(
    available: available,
    result: result,
  );
  final useCase = UnlockWithBiometricUseCase(
    cachedUserDao: db.cachedUserDao,
    settingsDao: db.biometricSettingsDao,
    biometricService: service,
  );
  return (
    useCase: useCase,
    db: db,
    settings: db.biometricSettingsDao,
    users: db.cachedUserDao,
    service: service,
  );
}

void main() {
  group('UnlockWithBiometricUseCase — short-circuits', () {
    test('no cached user → unavailable, hardware never queried', () async {
      final fx = _build();
      addTearDown(fx.db.close);

      final result = await fx.useCase.call(reason: 'Unlock');

      expect(result, BiometricUnlockResult.unavailable);
      expect(fx.service.isAvailableCalls, 0);
      expect(fx.service.authenticateCalls, 0);
    });

    test('user cached but biometric_on=false → unavailable, no prompt',
        () async {
      final fx = _build();
      addTearDown(fx.db.close);
      await fx.users.cacheUser(_alice);
      // settings table empty for this user → defaults to false.

      final result = await fx.useCase.call(reason: 'Unlock');

      expect(result, BiometricUnlockResult.unavailable);
      expect(fx.service.isAvailableCalls, 0,
          reason: 'must not query hardware before checking the pref');
      expect(fx.service.authenticateCalls, 0);
    });

    test('biometric_on=true but hardware unavailable → unavailable, no prompt',
        () async {
      final fx = _build(available: false);
      addTearDown(fx.db.close);
      await fx.users.cacheUser(_alice);
      await fx.settings.setEnabledFor('u-1', enabled: true);

      final result = await fx.useCase.call(reason: 'Unlock');

      expect(result, BiometricUnlockResult.unavailable);
      expect(fx.service.isAvailableCalls, 1);
      expect(fx.service.authenticateCalls, 0);
    });
  });

  group('UnlockWithBiometricUseCase — prompts the user', () {
    test('all preconditions met → forwards reason and returns success',
        () async {
      final fx = _build(result: BiometricUnlockResult.succeeded);
      addTearDown(fx.db.close);
      await fx.users.cacheUser(_alice);
      await fx.settings.setEnabledFor('u-1', enabled: true);

      final result = await fx.useCase.call(reason: 'Unlock to view orders');

      expect(result, BiometricUnlockResult.succeeded);
      expect(fx.service.authenticateCalls, 1);
      expect(fx.service.lastReason, 'Unlock to view orders');
    });

    test('user-cancel result is propagated, not coerced to unavailable',
        () async {
      final fx = _build(result: BiometricUnlockResult.cancelled);
      addTearDown(fx.db.close);
      await fx.users.cacheUser(_alice);
      await fx.settings.setEnabledFor('u-1', enabled: true);

      final result = await fx.useCase.call(reason: 'r');

      expect(result, BiometricUnlockResult.cancelled);
    });

    test('platform-error result is propagated as unavailable', () async {
      final fx = _build(result: BiometricUnlockResult.unavailable);
      addTearDown(fx.db.close);
      await fx.users.cacheUser(_alice);
      await fx.settings.setEnabledFor('u-1', enabled: true);

      final result = await fx.useCase.call(reason: 'r');

      expect(result, BiometricUnlockResult.unavailable);
    });
  });

  group('UnlockWithBiometricUseCase — keychain-only contract', () {
    test('the use case never reads or writes any crypto material itself',
        () async {
      // The use case has no SecretStore, no TokenStorage, no SecureStorage
      // dependency in its constructor — so it literally cannot touch
      // crypto material directly. This test exists to catch a future
      // refactor that would smuggle one in.
      final fx = _build();
      addTearDown(fx.db.close);
      await fx.users.cacheUser(_alice);
      await fx.settings.setEnabledFor('u-1', enabled: true);

      await fx.useCase.call(reason: 'r');

      // Settings table only stores the bool flag — `enabled` and
      // `enrolledAt`. Verify there's no crypto-looking column we
      // accidentally added.
      final row = await (fx.db.select(fx.db.biometricSettings)
            ..where((r) => r.userId.equals('u-1')))
          .getSingle();
      expect(row.toJson().keys.toSet(), {
        'userId',
        'enabled',
        'enrolledAt',
        'updatedAt',
      });
    });
  });
}
