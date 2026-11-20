import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// What is playing right now (one sound at a time in the whole app).
@immutable
class AudioPlayback {
  const AudioPlayback({
    this.key,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
  });

  /// Who is playing (a message id / local id). null = nothing loaded.
  final String? key;
  final bool playing;
  final Duration position;
  final Duration? duration;

  /// 0.0–1.0 for a progress bar.
  double get fraction {
    final total = duration?.inMilliseconds ?? 0;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      other is AudioPlayback &&
      other.key == key &&
      other.playing == playing &&
      other.position == position &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(key, playing, position, duration);
}

/// ONE audio player for the app (`just_audio`), so starting a voice message
/// stops the one before — like every chat app.
///
/// ```
/// bubble ▶ ──► toggle(key, source) ──► same key?  play / pause
///                                     other key → load + play (old one stops)
/// widgets listen to [playback] (ValueNotifier) → ▶/⏸ + progress
/// ```
class AppAudioPlayer {
  AppAudioPlayer() {
    _subs = [
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          // finished → back to the start, paused
          unawaited(_player.pause());
          unawaited(_player.seek(Duration.zero));
        }
        _update(
          playing: s.playing && s.processingState != ProcessingState.completed,
        );
      }),
      _player.positionStream.listen((p) => _update(position: p)),
      _player.durationStream.listen((d) => _update(duration: d)),
    ];
  }

  final AudioPlayer _player = AudioPlayer();
  late final List<StreamSubscription<Object?>> _subs;

  final ValueNotifier<AudioPlayback> playback = ValueNotifier(
    const AudioPlayback(),
  );

  /// Play / pause [key]. [source] is a URL (`http…`) or a file on the phone.
  Future<void> toggle(String key, String source) async {
    final now = playback.value;
    if (now.key == key) {
      return now.playing ? _player.pause() : _player.play();
    }
    playback.value = AudioPlayback(key: key);
    try {
      if (source.startsWith('http')) {
        await _player.setUrl(source);
      } else {
        await _player.setFilePath(source);
      }
      unawaited(_player.play());
    } catch (_) {
      playback.value = const AudioPlayback(); // couldn't load → idle
    }
  }

  /// Leaving the chat → stop the sound.
  Future<void> stop() async {
    await _player.stop();
    playback.value = const AudioPlayback();
  }

  void _update({bool? playing, Duration? position, Duration? duration}) {
    final now = playback.value;
    if (now.key == null) return;
    playback.value = AudioPlayback(
      key: now.key,
      playing: playing ?? now.playing,
      position: position ?? now.position,
      duration: duration ?? now.duration,
    );
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
  }
}
