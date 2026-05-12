import '../../domain/entities/otp_verification_result.dart';
import '../../domain/repositories/otp_repository.dart';

/// Placeholder [OtpRepository] used until the real MFA backend is wired.
///
/// Accepts a fixed dev code so the OTP page is end-to-end demoable on
/// the device, and rejects everything else with `incorrect`. The
/// 350 ms artificial latency lets the UI show its "submitting" spinner —
/// without it, the state transition is invisibly fast.
///
/// **Memory-only**: the [code] parameter is consumed inside the call and
/// never stored — no instance fields, no caches.
class StubOtpRepository implements OtpRepository {
  const StubOtpRepository();

  /// Canonical demo code. Documented as a constant so it surfaces in
  /// l10n hint copy without duplication.
  static const String devCode = '123456';

  @override
  Future<OtpVerificationResult> verify(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (code == devCode) {
      return const OtpVerificationResult.accepted();
    }
    return const OtpVerificationResult.rejected(
      reason: OtpRejectionReason.incorrect,
    );
  }
}
