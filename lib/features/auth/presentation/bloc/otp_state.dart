import '../../entities/otp_verification_result.dart';

/// Lifecycle of an OTP entry attempt.
enum OtpStatus { idle, submitting, success, error }

/// Sentinel so [OtpState.copyWith] can distinguish "leave unchanged" from
/// "set to null" for the nullable [rejectionReason] (matches freezed's
/// old copyWith semantics, which the bloc relies on to clear the error).
const Object _unset = Object();

/// Snapshot of the OTP page held by [OtpBloc].
///
/// Plain immutable value type (was `freezed`; the codegen was removed).
class OtpState {
  const OtpState({
    this.length = 6,
    this.code = '',
    this.status = OtpStatus.idle,
    this.rejectionReason,
  });

  /// Required length the bloc validates against.
  final int length;

  /// The digits typed so far. In memory only.
  final String code;

  final OtpStatus status;

  /// Populated when [status] is [OtpStatus.error].
  final OtpRejectionReason? rejectionReason;

  bool get isCompleteLength => code.length == length;
  bool get isSubmitting => status == OtpStatus.submitting;
  bool get hasError => status == OtpStatus.error;
  bool get hasSucceeded => status == OtpStatus.success;

  /// `true` when the form is ready for submission.
  bool get canSubmit => isCompleteLength && !isSubmitting;

  OtpState copyWith({
    int? length,
    String? code,
    OtpStatus? status,
    Object? rejectionReason = _unset,
  }) =>
      OtpState(
        length: length ?? this.length,
        code: code ?? this.code,
        status: status ?? this.status,
        rejectionReason: identical(rejectionReason, _unset)
            ? this.rejectionReason
            : rejectionReason as OtpRejectionReason?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OtpState &&
          other.length == length &&
          other.code == code &&
          other.status == status &&
          other.rejectionReason == rejectionReason);

  @override
  int get hashCode => Object.hash(length, code, status, rejectionReason);
}
