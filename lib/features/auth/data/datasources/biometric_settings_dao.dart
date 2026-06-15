import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences`-backed reader/writer for the per-user `biometric_on`
/// preference (the local SQLite database was removed).
///
/// Public API is unchanged. The bool flag lives here; the crypto material
/// stays in the OS keychain via `local_auth` — we never see actual keys.
class BiometricSettingsDao {
  BiometricSettingsDao(this._prefs);

  final SharedPreferences _prefs;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static const String _kEnabledPrefix = 'auth.biometric_on.';
  static const String _kEnrolledPrefix = 'auth.biometric_enrolled_at.';

  /// `true` only when the user explicitly opted in. Missing = `false`.
  Future<bool> isEnabledFor(String userId) async =>
      _prefs.getBool('$_kEnabledPrefix$userId') ?? false;

  /// Reactive variant for the Settings switch.
  Stream<bool> watchEnabledFor(String userId) async* {
    yield await isEnabledFor(userId);
    yield* _changes.stream.asyncMap((_) => isEnabledFor(userId));
  }

  /// Toggles the preference, capturing the opt-in moment for audit.
  Future<void> setEnabledFor(
    String userId, {
    required bool enabled,
    DateTime? enrolledAt,
  }) async {
    await _prefs.setBool('$_kEnabledPrefix$userId', enabled);
    if (enabled) {
      await _prefs.setString(
        '$_kEnrolledPrefix$userId',
        (enrolledAt ?? DateTime.now()).toIso8601String(),
      );
    } else {
      await _prefs.remove('$_kEnrolledPrefix$userId');
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Removes the preference for [userId].
  Future<int> deleteFor(String userId) async {
    final existed = _prefs.containsKey('$_kEnabledPrefix$userId');
    await _prefs.remove('$_kEnabledPrefix$userId');
    await _prefs.remove('$_kEnrolledPrefix$userId');
    if (!_changes.isClosed) _changes.add(null);
    return existed ? 1 : 0;
  }
}
