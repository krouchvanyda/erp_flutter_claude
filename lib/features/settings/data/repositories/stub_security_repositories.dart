import 'dart:async';

import '../../domain/entities/app_lock_settings.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/entities/device_session.dart';
import '../../domain/repositories/security_repositories.dart';
import '../settings_seed.dart';

class StubDeviceSessionsRepository implements DeviceSessionsRepository {
  StubDeviceSessionsRepository();

  static final List<DeviceSession> _seed =
      List<DeviceSession>.of(SettingsSeed.sessions);

  final StreamController<List<DeviceSession>> _changes =
      StreamController<List<DeviceSession>>.broadcast();

  @override
  Future<List<DeviceSession>> getAll() async {
    final out = List<DeviceSession>.of(_seed)
      // Current device first, then most recent activity.
      ..sort((a, b) {
        if (a.isCurrent && !b.isCurrent) return -1;
        if (b.isCurrent && !a.isCurrent) return 1;
        return b.lastActiveAt.compareTo(a.lastActiveAt);
      });
    return List.unmodifiable(out);
  }

  @override
  Stream<List<DeviceSession>> watchAll() async* {
    yield await getAll();
    yield* _changes.stream;
  }

  @override
  Future<void> revoke(String sessionId) async {
    _seed.removeWhere((s) => s.id == sessionId);
    _emit();
  }

  @override
  Future<void> revokeAllOthers() async {
    _seed.removeWhere((s) => !s.isCurrent);
    _emit();
  }

  Future<void> _emit() async {
    if (!_changes.isClosed) _changes.add(await getAll());
  }
}

class StubAuditLogRepository implements AuditLogRepository {
  StubAuditLogRepository();

  static final List<AuditLogEntry> _seed =
      List<AuditLogEntry>.of(SettingsSeed.auditLog);

  @override
  Future<List<AuditLogEntry>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<AuditLogEntry>> watchAll() async* {
    yield List.unmodifiable(_seed);
  }
}

class StubAppLockSettingsRepository implements AppLockSettingsRepository {
  StubAppLockSettingsRepository();

  static AppLockSettings _state = AppLockSettings.initial;
  final StreamController<AppLockSettings> _changes =
      StreamController<AppLockSettings>.broadcast();

  @override
  Future<AppLockSettings> get() async => _state;

  @override
  Stream<AppLockSettings> watch() async* {
    yield _state;
    yield* _changes.stream;
  }

  @override
  Future<AppLockSettings> update(AppLockSettings settings) async {
    _state = settings;
    if (!_changes.isClosed) _changes.add(_state);
    return _state;
  }
}

/// Memory-only PIN store for the demo.
///
/// **Why not the real `flutter_secure_storage`**: the integration would
/// land with the real auth slice. For now we hash the PIN with a
/// SHA-256-equivalent scramble so the test surface mirrors what the
/// real adapter will need (no plaintext, verify by re-hashing).
class InMemoryPinSecretStore implements PinSecretStore {
  static String? _hash;

  @override
  Future<bool> hasPin() async => _hash != null;

  @override
  Future<void> setPin(String pin) async {
    _hash = _scramble(pin);
  }

  @override
  Future<void> clearPin() async {
    _hash = null;
  }

  @override
  Future<bool> verifyPin(String pin) async {
    if (_hash == null) return false;
    return _hash == _scramble(pin);
  }

  String _scramble(String pin) {
    // Cheap deterministic scramble — a stand-in for the real hash. The
    // real adapter will use SHA-256 + per-install salt.
    final bytes = pin.codeUnits;
    var h = 0x12345678;
    for (final b in bytes) {
      h = ((h << 5) ^ (h >> 2) ^ b) & 0x7fffffff;
    }
    return h.toRadixString(16);
  }
}
