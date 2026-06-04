import 'package:equatable/equatable.dart';

/// Inputs to [OtpBloc].
sealed class OtpEvent extends Equatable {
  const OtpEvent();

  /// User edited the digits. Empty string is valid (clears the field).
  const factory OtpEvent.codeChanged(String code) = OtpCodeChanged;

  /// User tapped "Verify". The bloc validates length, then calls the
  /// use case.
  const factory OtpEvent.submitted() = OtpSubmitted;

  /// Reset the page back to its initial state (e.g. after popping back
  /// from a "resend" flow — placeholder for future slice).
  const factory OtpEvent.cleared() = OtpCleared;
}

class OtpCodeChanged extends OtpEvent {
  const OtpCodeChanged(this.code);
  final String code;
  @override
  List<Object?> get props => [code];
}

class OtpSubmitted extends OtpEvent {
  const OtpSubmitted();
  @override
  List<Object?> get props => const [];
}

class OtpCleared extends OtpEvent {
  const OtpCleared();
  @override
  List<Object?> get props => const [];
}
