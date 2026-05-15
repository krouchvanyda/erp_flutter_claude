import 'dart:async';

import '../../domain/entities/user_preferences.dart';
import '../../domain/repositories/preferences_repository.dart';

/// In-memory preferences store for the demo. Real implementation will
/// persist to drift (`user_preferences` table) — not into
/// `flutter_secure_storage` since these aren't secrets.
class StubPreferencesRepository implements PreferencesRepository {
  StubPreferencesRepository();

  static UserPreferences _state = UserPreferences.initial;
  final StreamController<UserPreferences> _changes =
      StreamController<UserPreferences>.broadcast();

  @override
  Future<UserPreferences> get() async => _state;

  @override
  Stream<UserPreferences> watch() async* {
    yield _state;
    yield* _changes.stream;
  }

  @override
  Future<UserPreferences> setThemeMode(AppThemeMode mode) async {
    _state = _state.copyWith(themeMode: mode);
    _emit();
    return _state;
  }

  @override
  Future<UserPreferences> setLanguage(AppLanguage language) async {
    _state = _state.copyWith(language: language);
    _emit();
    return _state;
  }

  @override
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
