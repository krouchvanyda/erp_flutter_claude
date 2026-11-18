import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import 'call_signaling_service.dart';

/// Which call sound to play (files in `assets/sounds/`).
enum CallSound {
  /// Caller hears this while the peer's phone rings (loops).
  ringback('assets/sounds/call_ringback.wav', loop: true),

  /// Incoming call while the app is open (loops).
  ringtone('assets/sounds/call_ringtone.wav', loop: true),

  /// Call just connected (once).
  connected('assets/sounds/call_connected.wav'),

  /// Call ended / rejected / missed (once).
  ended('assets/sounds/call_ended.wav');

  const CallSound(this.asset, {this.loop = false});
  final String asset;
  final bool loop;
}

/// Plays call sounds by watching [CallSignalingService.activeCallListenable]:
///
/// | state change                      | sound                     |
/// |-----------------------------------|---------------------------|
/// | → outgoingRinging ("Calling…")    | silence                   |
/// | callee's phone rings ("Ringing…") | ringback (loop)           |
/// | → incomingRinging, app open       | ringtone (loop)           |
/// | ringing → connected               | connected beep            |
/// | ringing/connected → ended or gone | ended beep                |
///
/// Incoming ringing in the background is NOT played here — CallKit /
/// the native call notification already ring, so we'd ring twice.
///
/// Never touches the audio session (`handleAudioSessionActivation:
/// false`): the call's audio session belongs to WebRTC / CallKit
/// (see `StreamCallEngine`), and changing it can mute the call.
class CallSoundPlayer {
  CallSoundPlayer._();

  static final CallSoundPlayer instance = CallSoundPlayer._();

  AudioPlayer? _player;
  ValueListenable<ActiveCall?>? _source;
  ActiveCall? _prev;

  /// True while a ringing loop plays. "No sound" only stops a loop — a
  /// one-shot beep (connected / ended) is left to finish.
  bool _looping = false;

  /// Start listening. Safe to call more than once.
  void attach(ValueListenable<ActiveCall?> activeCall) {
    if (identical(_source, activeCall)) return;
    _source?.removeListener(_onChanged);
    _source = activeCall..addListener(_onChanged);
    _prev = activeCall.value;
  }

  void _onChanged() {
    final next = _source?.value;
    final prev = _prev;
    _prev = next;
    final appOpen =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final sameCall = prev?.callId == next?.callId;
    final prevPeerRinging = prev?.peerRinging ?? false;
    final nextPeerRinging = next?.peerRinging ?? false;
    // Same call, same state, same "peer ringing" (e.g. `connectedAt`
    // filled in) → nothing.
    if (sameCall &&
        prev?.state == next?.state &&
        prevPeerRinging == nextPeerRinging) {
      return;
    }
    final sound = soundFor(
      prev: prev?.state,
      next: next?.state,
      sameCall: sameCall,
      appOpen: appOpen,
      prevPeerRinging: prevPeerRinging,
      nextPeerRinging: nextPeerRinging,
    );
    if (sound == null && !_looping) return;
    unawaited(_play(sound));
  }

  /// Pure rule table (unit-tested). `null` = no new sound (a ringing
  /// loop, if any, is stopped).
  @visibleForTesting
  static CallSound? soundFor({
    required CallSignalState? prev,
    required CallSignalState? next,
    required bool sameCall,
    required bool appOpen,
    bool prevPeerRinging = false,
    bool nextPeerRinging = false,
  }) {
    final changed =
        !sameCall || prev != next || prevPeerRinging != nextPeerRinging;
    if (!changed) return null;
    switch (next) {
      case CallSignalState.outgoingRinging:
        // Silent while "Calling…"; the ringback starts only once the
        // callee's phone reports it is ringing ("Ringing…").
        return nextPeerRinging ? CallSound.ringback : null;
      case CallSignalState.incomingRinging:
        return appOpen ? CallSound.ringtone : null;
      case CallSignalState.connected:
        return sameCall && _isRinging(prev) ? CallSound.connected : null;
      case CallSignalState.ended:
        return sameCall && _wasLive(prev) ? CallSound.ended : null;
      case CallSignalState.idle:
      case null:
        // Torn down without an `ended` step (some paths jump to null).
        return _wasLive(prev) ? CallSound.ended : null;
    }
  }

  static bool _isRinging(CallSignalState? s) =>
      s == CallSignalState.outgoingRinging ||
      s == CallSignalState.incomingRinging;

  static bool _wasLive(CallSignalState? s) =>
      _isRinging(s) || s == CallSignalState.connected;

  Future<void> _play(CallSound? sound) async {
    try {
      final player = _player ??=
          AudioPlayer(handleAudioSessionActivation: false);
      await player.stop();
      _looping = sound?.loop ?? false;
      if (sound == null) return;
      await player.setAsset(sound.asset);
      await player.setLoopMode(sound.loop ? LoopMode.one : LoopMode.off);
      unawaited(player.play());
    } catch (e) {
      // A sound must never break a call.
      debugPrint('[CallSound] $sound failed: $e');
    }
  }

  /// Stop any sound (e.g. on sign-out).
  Future<void> stop() async {
    _looping = true; // force the stop below
    await _play(null);
  }
}
