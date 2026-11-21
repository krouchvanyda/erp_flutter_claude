import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import '../model/call_sound.dart';

/// Plays ONE call sound at a time (Step 6.3a). A new sound replaces the old
/// one; [CallSound.silence] just stops.
///
/// It never touches the phone's audio session: during a call that session
/// belongs to WebRTC (Stream), and changing it can MUTE the call
/// (CALL_SCENARIOS.md: "In-app sounds never change the call's audio
/// settings"). Hence the three `false` flags below.
///
/// Separate from `AppAudioPlayer` (voice messages): a ringtone must not stop
/// the voice note you were listening to through that player's rules, and
/// vice versa.
class CallSounds with WidgetsBindingObserver {
  CallSounds({AudioPlayer Function()? createPlayer})
    : _createPlayer = createPlayer ?? _defaultPlayer;

  /// A ringtone asked for while the app was in the background (the ring
  /// NOTIFICATION rings then, 7.2) → played when the app comes back.
  CallSound? _waiting;

  /// Start following the app (foreground / background). Call once.
  void attach() => WidgetsBinding.instance.addObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final waiting = _waiting;
    if (state == AppLifecycleState.resumed && waiting != null) {
      _waiting = null;
      play(waiting);
    }
  }

  static AudioPlayer _defaultPlayer() => AudioPlayer(
    handleAudioSessionActivation: false,
    handleInterruptions: false,
    androidApplyAudioAttributes: false,
  );

  final AudioPlayer Function() _createPlayer;
  AudioPlayer? _player;

  /// Best effort: a sound that can't play must never break a call.
  Future<void> play(CallSound sound) async {
    _waiting = null;
    // In the background the ring notification rings (7.2): never two rings.
    final inFront =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (sound == CallSound.ringtone && !inFront) {
      _waiting = sound;
      return;
    }
    try {
      final player = _player ??= _createPlayer();
      await player.stop();
      final asset = sound.asset;
      if (asset == null) return; // silence
      await player.setAsset(asset);
      await player.setLoopMode(sound.loop ? LoopMode.one : LoopMode.off);
      unawaited(player.play()); // play() completes when it STOPS playing
    } catch (e) {
      debugPrint('[CallSounds] $sound failed: $e');
    }
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
