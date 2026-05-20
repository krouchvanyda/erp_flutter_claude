import 'package:get_it/get_it.dart';

import 'data/repositories/admin_repositories.dart';
import 'data/repositories/preferences_repository.dart';
import 'data/repositories/security_repositories.dart';

/// Manual DI registration for Module 9 (Settings & Administration).
///
/// Same pattern as Modules 4–8: avoids re-running build_runner per
/// repo tweak. Call once from `main.dart` after `configureDependencies()`.
void registerSettingsModule(GetIt getIt) {
  // Phase 9.1 — preferences.
  if (!getIt.isRegistered<PreferencesRepository>()) {
    getIt.registerLazySingleton<PreferencesRepository>(
      PreferencesRepository.new,
    );
  }
  // Phase 9.2 — admin.
  if (!getIt.isRegistered<ManagedUsersRepository>()) {
    getIt.registerLazySingleton<ManagedUsersRepository>(
      ManagedUsersRepository.new,
    );
  }
  if (!getIt.isRegistered<RolesRepository>()) {
    getIt.registerLazySingleton<RolesRepository>(
      RolesRepository.new,
    );
  }
  if (!getIt.isRegistered<ApiEnvironmentsRepository>()) {
    getIt.registerLazySingleton<ApiEnvironmentsRepository>(
      ApiEnvironmentsRepository.new,
    );
  }
  // Phase 9.3 — security.
  if (!getIt.isRegistered<DeviceSessionsRepository>()) {
    getIt.registerLazySingleton<DeviceSessionsRepository>(
      DeviceSessionsRepository.new,
    );
  }
  if (!getIt.isRegistered<AuditLogRepository>()) {
    getIt.registerLazySingleton<AuditLogRepository>(
      AuditLogRepository.new,
    );
  }
  if (!getIt.isRegistered<AppLockSettingsRepository>()) {
    getIt.registerLazySingleton<AppLockSettingsRepository>(
      AppLockSettingsRepository.new,
    );
  }
  if (!getIt.isRegistered<InMemoryPinSecretStore>()) {
    getIt.registerLazySingleton<InMemoryPinSecretStore>(
      InMemoryPinSecretStore.new,
    );
  }
}
