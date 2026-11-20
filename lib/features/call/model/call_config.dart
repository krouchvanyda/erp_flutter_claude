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

  /// My network dropped during a call: "Reconnecting…" for at most this
  /// long, then the call ends ("Connection lost"). Same as the backend's
  /// `answered-disconnect-grace-seconds`, which hangs up for a phone whose
  /// socket is gone this long (Step 6.3b, CALL_SCENARIOS.md #8).
  static const Duration reconnectTimeout = Duration(seconds: 30);

  /// How long "Call ended" / "Call declined" stays before the screen closes.
  static const Duration endedScreen = Duration(milliseconds: 1500);
}
