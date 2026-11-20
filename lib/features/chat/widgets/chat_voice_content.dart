import 'package:flutter/material.dart';

import '../../../core/audio/app_audio_player.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// A voice message inside a bubble.
///
/// ```
/// (▶)  ━━━━━━━○──────────  0:12
/// ```
/// One [AppAudioPlayer] for the app: pressing ▶ here stops any other voice.
/// While it plays, the time counts the position; otherwise the length.
class ChatVoiceContent extends StatelessWidget {
  const ChatVoiceContent({
    super.key,
    required this.playKey,
    required this.source,
    required this.player,
    required this.isMine,
    this.durationSeconds,
  });

  /// Who is playing (message id / local id).
  final String playKey;

  /// A URL or a file on the phone (my voice note while it uploads).
  /// null → can't play yet.
  final String? source;
  final AppAudioPlayer player;
  final bool isMine;
  final int? durationSeconds;

  static String clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fg = isMine ? colors.onPrimary : colors.primary;
    final track = isMine
        ? colors.onPrimary.withValues(alpha: 0.3)
        : colors.outline.withValues(alpha: 0.35); // visible on the grey bubble
    final soft = isMine
        ? colors.onPrimary.withValues(alpha: 0.75)
        : colors.onSurfaceVariant;

    return ValueListenableBuilder<AudioPlayback>(
      valueListenable: player.playback,
      builder: (context, playback, _) {
        final mine = playback.key == playKey;
        final playing = mine && playback.playing;
        final length = Duration(seconds: durationSeconds ?? 0);
        final label = mine && playback.position > Duration.zero
            ? clock(playback.position)
            : clock(playback.duration ?? length);

        return SizedBox(
          width: 210,
          child: Row(
            children: [
              Semantics(
                button: true,
                label: playing ? 'Pause voice message' : 'Play voice message',
                child: InkResponse(
                  onTap: source == null
                      ? null
                      : () => player.toggle(playKey, source!),
                  radius: 24,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isMine ? colors.onPrimary : colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: isMine ? colors.primary : colors.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: mine ? playback.fraction : 0,
                    minHeight: 4,
                    color: fg,
                    backgroundColor: track,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppLabel(
                text: label,
                fontSize: AppFontSize.value12,
                fontWeight: FontWeight.w600,
                color: soft,
              ),
            ],
          ),
        );
      },
    );
  }
}
