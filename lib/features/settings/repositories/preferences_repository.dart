import 'dart:async';

import '../models/user_preferences.dart';

/// Slice 9.1.x — single repository for the device-local preferences
/// snapshot. Granular updates flow through the typed setters so the
/// repo can validate / persist atomically and emit one new
/// [UserPreferences] on the broadcast stream.
///
/// In-memory preferences store for the demo. Real implementation will
/// persist to drift (`user_preferences` table) — not into
/// `flutter_secure_storage` since these aren't secrets.
class PreferencesRepository {
  PreferencesRepository();

  static UserPreferences _state = UserPreferences.initial;
  final StreamController<UserPreferences> _changes =
      StreamController<UserPreferences>.broadcast();

  Future<UserPreferences> get() async => _state;

  Stream<UserPreferences> watch() async* {
    yield _state;
    yield* _changes.stream;
  }

  Future<UserPreferences> setThemeMode(AppThemeMode mode) async {
    _state = _state.copyWith(themeMode: mode);
    _emit();
    return _state;
  }

  Future<UserPreferences> setNotificationPref(
      NotificationChannelPref pref) async {
    final next = [
      for (final p in _state.notificationChannels)
        if (p.channel == pref.channel) pref else p,
    ];
    _state = _state.copyWith(notificationChannels: next);
    _emit();
    return _state;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(_state);
  }
}
