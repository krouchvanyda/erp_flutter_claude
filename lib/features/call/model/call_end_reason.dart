/// Why the call screen says goodbye. Each one has its own text, so the user
/// always knows WHAT happened (lesson from flutter-chat, CALL_SCENARIOS.md).
enum CallEndReason {
  /// Someone hung up a call that was connected.
  hungUp('Call ended'),

  /// The callee tapped Decline (seen by both sides).
  declined('Call declined'),

  /// Nobody answered in time (the server's 60 s, or our backstop).
  noAnswer('No answer'),

  /// I (the caller) hung up while it was still ringing. Scenario 13.
  cancelled('Call cancelled'),

  /// The callee is already in another call. Scenario 11.
  busy('Busy in another call'),

  /// It rang on my phone, but the caller gave up / nobody answered.
  missed('Missed call'),

  /// I answered on another device of mine.
  answeredElsewhere('Answered on another device'),

  /// The server still counts ME in an open call ("Caller is already in an
  /// active call"), e.g. an earlier call whose app died. The server hangs up
  /// such calls itself ~30 s after the app's socket is gone.
  stillInCall("You're still in another call. Try again in a moment."),

  /// My network was gone too long during the call (Step 6.3b).
  connectionLost('Connection lost'),

  /// The start / accept request failed (the state carries the reason).
  failed("Couldn't connect the call");

  const CallEndReason(this.label);

  /// The default text. `failed` shows the server's message when there is one.
  final String label;
}
