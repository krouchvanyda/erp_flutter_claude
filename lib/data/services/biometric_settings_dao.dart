import 'package:rxdart/rxdart.dart';

/// In-memory reader/writer for the per-user `biometric_on` preference.
///
/// **Local persistence removed** — was a drift accessor; now a
/// process-lifetime in-memory store. The flag resets to `false` on a
/// cold start (the OS keychain still holds the actual biometric crypto
/// material via `local_auth`; only the opt-in bool lived here). Public
/// API unchanged so `AuthRepository` + the Settings switch keep working.
class BiometricSettingsDao {
  final Map<String, bool> _enabled = <String, bool>{};
  final Map<String, BehaviorSubject<bool>> _subjects =
      <String, BehaviorSubject<bool>>{};

  BehaviorSubject<bool> _subjectFor(String userId) => _subjects.putIfAbsent(
        userId,
        () => BehaviorSubject<bool>.seeded(_enabled[userId] ?? false),
      );

  Future<bool> isEnabledFor(String userId) async => _enabled[userId] ?? false;

  Stream<bool> watchEnabledFor(String userId) => _subjectFor(userId).stream;

  Future<void> setEnabledFor(
    String userId, {
    required bool enabled,
    DateTime? enrolledAt,
  }) async {
    _enabled[userId] = enabled;
    final s = _subjects[userId];
    if (s != null) s.add(enabled);
  }

  Future<int> deleteFor(String userId) async {
    final existed = _enabled.remove(userId) != null;
    final s = _subjects[userId];
    if (s != null) s.add(false);
    return existed ? 1 : 0;
  }

  Future<void> dispose() async {
    for (final s in _subjects.values) {
      await s.close();
    }
    _subjects.clear();
  }
}
