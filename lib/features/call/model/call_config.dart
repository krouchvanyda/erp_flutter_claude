/// All call timings in ONE place (idea from flutter-chat's `CallConfig`).
/// Change a value here, nowhere else.
abstract final class CallConfig {
  /// The SERVER ends an unanswered call after this (`ring-timeout-seconds`
  /// in the backend's application.yml) and sends `call.hangup`
  /// `reason: no_answer`. Shown in docs; the app waits for that event.
  static const Duration serverRingTimeout = Duration(seconds: 60);

  /// Our backstop, in case the server's `call.hangup` is lost (socket down).
  /// LONGER than [serverRingTimeout], so normally the server decides.
  ///
  /// The callee's backstop only CLOSES the screen. It never sends "reject":
  /// that would save the call as "declined" instead of "missed"
  /// (CALL_SCENARIOS.md #19 — a bug in the old app).
  static const Duration ringBackstop = Duration(seconds: 70);

  /// How long "Call ended" / "Call declined" stays before the screen closes.
  static const Duration endedScreen = Duration(milliseconds: 1500);
}
