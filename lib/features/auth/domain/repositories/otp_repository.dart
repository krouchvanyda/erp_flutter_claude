import '../entities/otp_verification_result.dart';

/// Domain contract for verifying a one-time / time-based code.
///
/// Lives in `domain/` and imports nothing from `dio` / `drift` /
/// `flutter_secure_storage` — concrete implementations sit in
/// `data/repositories/`. Slice 1.2.1 ships a stub that accepts the
/// canonical dev code `123456`; the real backend-bound impl lands in a
/// later MFA slice.
///
/// **Memory-only contract** (per CLAUDE.md Slice 1.2.1): no
/// implementation may persist the submitted [code] to drift,
/// `shared_preferences`, secure storage, or any other long-lived sink.
/// The code is held in the BLoC state for the duration of the page only.
abstract class OtpRepository {
  Future<OtpVerificationResult> verify(String code);
}
