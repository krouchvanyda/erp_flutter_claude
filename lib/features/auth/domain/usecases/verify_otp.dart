import '../entities/otp_verification_result.dart';
import '../repositories/otp_repository.dart';

/// "Submit one OTP attempt" — the only business action this slice owns.
///
/// Trivially delegates to [OtpRepository.verify]; the use case exists so
/// the bloc depends on a stable domain seam (and tests can swap a fake
/// without taking on the repository's testing surface).
class VerifyOtpUseCase {
  const VerifyOtpUseCase({required OtpRepository repository})
      : _repository = repository;

  final OtpRepository _repository;

  Future<OtpVerificationResult> call(String code) => _repository.verify(code);
}
