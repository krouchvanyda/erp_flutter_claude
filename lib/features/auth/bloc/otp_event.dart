/// Inputs to [OtpBloc].
///
/// Plain Dart 3 `sealed class` (was `freezed`). Construction via
/// `OtpEvent.codeChanged(...)` etc. is preserved through factory redirects;
/// the bloc's `on<OtpCodeChanged>` handlers match the subtypes.
sealed class OtpEvent {
  const OtpEvent();

  /// User edited the digits. Empty string is valid (clears the field).
  const factory OtpEvent.codeChanged(String code) = OtpCodeChanged;

  /// User tapped "Verify".
  const factory OtpEvent.submitted() = OtpSubmitted;

  /// Reset the page back to its initial state.
  const factory OtpEvent.cleared() = OtpCleared;
}

class OtpCodeChanged extends OtpEvent {
  const OtpCodeChanged(this.code);
  final String code;
}

class OtpSubmitted extends OtpEvent {
  const OtpSubmitted();
}

class OtpCleared extends OtpEvent {
  const OtpCleared();
}
