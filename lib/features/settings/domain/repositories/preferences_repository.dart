import '../entities/user_preferences.dart';

/// Slice 9.1.x — single repository for the device-local preferences
/// snapshot. Granular updates flow through the typed setters so the
/// repo can validate / persist atomically and emit one new
/// [UserPreferences] on the broadcast stream.
abstract class PreferencesRepository {
  Future<UserPreferences> get();
  Stream<UserPreferences> watch();

  Future<UserPreferences> setThemeMode(AppThemeMode mode);
  Future<UserPreferences> setLanguage(AppLanguage language);
  Future<UserPreferences> setNotificationPref(NotificationChannelPref pref);
}
