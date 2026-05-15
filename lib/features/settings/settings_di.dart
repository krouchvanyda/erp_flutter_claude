import 'package:get_it/get_it.dart';

import 'data/repositories/stub_admin_repositories.dart';
import 'data/repositories/stub_preferences_repository.dart';
import 'data/repositories/stub_security_repositories.dart';
import 'domain/repositories/admin_repositories.dart';
import 'domain/repositories/preferences_repository.dart';
import 'domain/repositories/security_repositories.dart';

/// Manual DI registration for Module 9 (Settings & Administration).
///
/// Same pattern as Modules 4–8: avoids re-running build_runner per
/// repo tweak. Call once from `main.dart` after `configureDependencies()`.
void registerSettingsModule(GetIt getIt) {
  // Phase 9.1 — preferences.
  if (!getIt.isRegistered<PreferencesRepository>()) {
    getIt.registerLazySingleton<PreferencesRepository>(
      StubPreferencesRepository.new,
    );
  }
  // Phase 9.2 — admin.
  if (!getIt.isRegistered<ManagedUsersRepository>()) {
    getIt.registerLazySingleton<ManagedUsersRepository>(
      StubManagedUsersRepository.new,
    );
  }
  if (!getIt.isRegistered<RolesRepository>()) {
    getIt.registerLazySingleton<RolesRepository>(
      StubRolesRepository.new,
    );
  }
  if (!getIt.isRegistered<ApiEnvironmentsRepository>()) {
    getIt.registerLazySingleton<ApiEnvironmentsRepository>(
      StubApiEnvironmentsRepository.new,
    );
  }
  // Phase 9.3 — security.
  if (!getIt.isRegistered<DeviceSessionsRepository>()) {
    getIt.registerLazySingleton<DeviceSessionsRepository>(
      StubDeviceSessionsRepository.new,
    );
  }
  if (!getIt.isRegistered<AuditLogRepository>()) {
    getIt.registerLazySingleton<AuditLogRepository>(
      StubAuditLogRepository.new,
    );
  }
  if (!getIt.isRegistered<AppLockSettingsRepository>()) {
    getIt.registerLazySingleton<AppLockSettingsRepository>(
      StubAppLockSettingsRepository.new,
    );
  }
  if (!getIt.isRegistered<PinSecretStore>()) {
    getIt.registerLazySingleton<PinSecretStore>(
      InMemoryPinSecretStore.new,
    );
  }
}
