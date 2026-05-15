import '../entities/app_lock_settings.dart';
import '../entities/audit_log_entry.dart';
import '../entities/device_session.dart';

/// Slice 9.3.1 — active devices.
abstract class DeviceSessionsRepository {
  Future<List<DeviceSession>> getAll();
  Stream<List<DeviceSession>> watchAll();

  /// Caller must guard against revoking [DeviceSession.isCurrent] —
  /// the use case enforces that, this just removes the row.
  Future<void> revoke(String sessionId);
  Future<void> revokeAllOthers();
}

/// Slice 9.3.2 — audit log read API. Append happens server-side; the
/// app only reads.
abstract class AuditLogRepository {
  Future<List<AuditLogEntry>> getAll();
  Stream<List<AuditLogEntry>> watchAll();
}

/// Slice 9.3.3 — PIN + biometric lock settings.
///
/// **Storage split**:
/// - the toggles + autoLockMinutes live in this (drift-backed) repo
/// - the PIN hash itself lives in `flutter_secure_storage` via
///   [PinSecretStore]. Wiping drift never wipes the PIN; logging out
///   clears both.
abstract class AppLockSettingsRepository {
  Future<AppLockSettings> get();
  Stream<AppLockSettings> watch();
  Future<AppLockSettings> update(AppLockSettings settings);
}

/// Memory-only PIN store for the demo (real impl plugs into
/// `flutter_secure_storage`). Returns a *hash* of the PIN, not the PIN
/// itself, so an attacker with read access to the store still can't
/// recover the secret.
abstract class PinSecretStore {
  Future<bool> hasPin();
  Future<void> setPin(String pin);
  Future<void> clearPin();
  Future<bool> verifyPin(String pin);
}
