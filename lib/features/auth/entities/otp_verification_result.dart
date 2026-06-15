/// Why the server / verifier turned a code down.
enum OtpRejectionReason {
  /// Digits didn't match the expected code.
  incorrect,

  /// Code was valid in the past but the validity window has elapsed.
  expired,

  /// Server is throttling further attempts (rate limit / lockout).
  tooManyAttempts,

  /// Transport failure — we couldn't reach the verifier.
  networkError,
}

/// Outcome of a single OTP submission.
///
/// Sealed so callers pattern-match exhaustively. Plain Dart 3 `sealed
/// class` (was `freezed`; the codegen was removed). Construction via
/// `OtpVerificationResult.accepted()` / `.rejected(reason:)` is preserved
/// through the factory redirects.
sealed class OtpVerificationResult {
  const OtpVerificationResult();

  const factory OtpVerificationResult.accepted() = OtpAccepted;
  const factory OtpVerificationResult.rejected({
    required OtpRejectionReason reason,
  }) = OtpRejected;
}

class OtpAccepted extends OtpVerificationResult {
  const OtpAccepted();
}

class OtpRejected extends OtpVerificationResult {
  const OtpRejected({required this.reason});
  final OtpRejectionReason reason;
}
