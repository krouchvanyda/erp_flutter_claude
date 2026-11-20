/// The call sounds (files in `assets/sounds/`). Step 6.3a.
///
/// Like a real phone (CALL_SCENARIOS.md "Call sounds"): the caller hears
/// NOTHING while "Calling…", the "tuut… tuut" only once the other phone
/// really rings ("Ringing…").
enum CallSound {
  /// Caller: their phone is ringing (loops).
  ringback('assets/sounds/call_ringback.wav', loop: true),

  /// Callee: someone calls me, app open (loops).
  ringtone('assets/sounds/call_ringtone.wav', loop: true),

  /// Both: the other person is really in the call (once).
  connected('assets/sounds/call_connected.wav'),

  /// Both: the call ended / was declined / missed / cancelled (once).
  ended('assets/sounds/call_ended.wav'),

  /// Stop a ringing loop, play nothing.
  silence(null);

  const CallSound(this.asset, {this.loop = false});

  final String? asset;
  final bool loop;
}
