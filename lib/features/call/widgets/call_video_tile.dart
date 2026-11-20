import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart'
    hide CallMember; // ours (model/call_peer.dart) has the same name

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/call_peer.dart';

/// One person in a video call: their camera, or their photo when it's off.
/// [showName] → a small name pill at the bottom (group grid, 6.3c).
class CallVideoTile extends StatelessWidget {
  const CallVideoTile({
    super.key,
    required this.call,
    required this.participant,
    required this.member,
    this.showName = false,
    this.avatarSize = 112,
  });

  final Call call;
  final CallParticipantState participant;
  final CallMember member;
  final bool showName;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photo = ColoredBox(
      color: colors.surfaceContainerLowest,
      child: Center(
        child: AppAvatar(
          name: member.name,
          imageUrl: member.avatarUrl,
          size: avatarSize,
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (participant.isVideoEnabled)
          StreamVideoRenderer(
            call: call,
            participant: participant,
            videoTrackType: SfuTrackType.video,
            placeholderBuilder: (_) => photo,
          )
        else
          photo,
        if (showName && member.name.isNotEmpty)
          PositionedDirectional(
            start: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.scrim.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!participant.isAudioEnabled) ...[
                      Icon(
                        Icons.mic_off_rounded,
                        size: 14,
                        color: colors.onSurface,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    AppLabel(
                      text: member.firstName,
                      fontSize: AppFontSize.value12,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
