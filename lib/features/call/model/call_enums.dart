// Call enums — the same names as the backend (`entity/CallType`,
// `CallStatus`, `ParticipantStatus`). `fromJson` never crashes: an unknown
// value falls back to a safe default.

/// `VOICE` or `VIDEO`.
enum CallType {
  voice,
  video;

  static CallType fromJson(Object? value) => value == 'VIDEO' ? video : voice;

  /// For requests: `CallType.video` → `"VIDEO"`.
  String toJson() => name.toUpperCase();
}

/// The whole call: `RINGING` → `ANSWERED` → `ENDED`, or it stops early as
/// `MISSED` / `REJECTED` / `BUSY`.
enum CallStatus {
  ringing,
  answered,
  ended,
  missed,
  rejected,
  busy;

  static CallStatus fromJson(Object? value) => switch (value) {
    'RINGING' => ringing,
    'ANSWERED' => answered,
    'MISSED' => missed,
    'REJECTED' => rejected,
    'BUSY' => busy,
    _ => ended, // unknown → "it's over" (never a stuck call screen)
  };

  /// The call is finished: nobody can join it any more.
  bool get isOver => this != ringing && this != answered;
}

/// One person in the call.
enum ParticipantStatus {
  ringing,
  answered,
  rejected,
  left,
  missed;

  static ParticipantStatus fromJson(Object? value) => switch (value) {
    'RINGING' => ringing,
    'ANSWERED' => answered,
    'REJECTED' => rejected,
    'MISSED' => missed,
    _ => left,
  };
}
