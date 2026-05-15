import '../../../../core/error/failure.dart';
import '../entities/device_session.dart';

/// Slice 9.3.1 — refuse to revoke the current device, since that
/// would log the user out of the screen they're standing on. They can
/// use the global "Sign out" affordance for that.
void ensureSessionIsRevocable(DeviceSession session) {
  if (session.isCurrent) {
    throw ConflictFailure(
        message:
            'Use Sign out to end the current session. Revoke other devices instead.');
  }
}
