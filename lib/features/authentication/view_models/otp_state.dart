import 'package:erp_mobile/features/authentication/models/otp_verification_result_model.dart';

/// Lifecycle of an OTP entry attempt.
enum OtpStatus { idle, submitting, success, error }

/// Snapshot of the OTP page held by [OtpViewModel].
///
/// Single class (not a sealed union per status) because every status
/// shares the same scalar fields — exhaustive switching happens in the
/// view via [OtpStatus] enum + the optional [rejectionReason] tag.
class OtpState {
  const OtpState({
    this.length = 6,
    this.code = '',
    this.status = OtpStatus.idle,
    this.rejectionReason,
  });

  /// Required length the bloc validates against. Configurable so the
  /// same widget can drive 4-, 6-, or 8-digit codes.
  final int length;

  /// The digits the user has typed so far. Held **in memory only** —
  /// never persisted to drift / secure-storage / shared_preferences.
  final String code;

  final OtpStatus status;

  /// Populated when [status] is [OtpStatus.error]. Drives the
  /// per-reason localised error copy in the view.
  final OtpRejectionReason? rejectionReason;

  bool get isCompleteLength => code.length == length;
  bool get isSubmitting => status == OtpStatus.submitting;
  bool get hasError => status == OtpStatus.error;
  bool get hasSucceeded => status == OtpStatus.success;

  /// `true` when the form is ready for submission — exact length and not
  /// already waiting on a previous attempt.
  bool get canSubmit => isCompleteLength && !isSubmitting;

  static const Object _undefined = Object();

  OtpState copyWith({
    int? length,
    String? code,
    OtpStatus? status,
    Object? rejectionReason = _undefined,
  }) {
    return OtpState(
      length: length ?? this.length,
      code: code ?? this.code,
      status: status ?? this.status,
      rejectionReason: identical(rejectionReason, _undefined)
          ? this.rejectionReason
          : rejectionReason as OtpRejectionReason?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpState &&
          runtimeType == other.runtimeType &&
          length == other.length &&
          code == other.code &&
          status == other.status &&
          rejectionReason == other.rejectionReason;

  @override
  int get hashCode =>
      Object.hash(runtimeType, length, code, status, rejectionReason);
}
