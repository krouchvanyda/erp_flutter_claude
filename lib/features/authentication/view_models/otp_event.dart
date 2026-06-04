/// Inputs to [OtpViewModel].
sealed class OtpEvent {
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpCodeChanged &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => Object.hash(runtimeType, code);
}

class OtpSubmitted extends OtpEvent {
  const OtpSubmitted();
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpSubmitted && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class OtpCleared extends OtpEvent {
  const OtpCleared();
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpCleared && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
