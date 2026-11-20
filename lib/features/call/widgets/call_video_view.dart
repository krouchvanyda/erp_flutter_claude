import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/call_peer.dart';

/// The picture of a video call (Step 6.2):
///
/// ```
/// ┌──────────────────────────┐
/// │                  ┌─────┐ │
/// │   THEIR camera   │ me  │ │  ← my camera, small (only when it's on)
/// │   (full screen)  └─────┘ │
/// │                          │
/// └──────────────────────────┘
/// ```
/// Their camera off / not here yet → their photo on a dark background.
/// The only widget that draws Stream video (`StreamVideoRenderer`).
class CallVideoView extends StatelessWidget {
  const CallVideoView({
    super.key,
    required this.call,
    required this.peer,
    required this.myCameraOn,
  });

  /// The joined Stream call (`CallMedia.call`), null while joining.
  final ValueListenable<Call?> call;
  final CallPeer peer;
  final bool myCameraOn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerLowest,
      child: Center(
        child: AppAvatar(name: peer.name, imageUrl: peer.avatarUrl, size: 112),
      ),
    );

    return ValueListenableBuilder<Call?>(
      valueListenable: call,
      builder: (context, joined, _) {
        if (joined == null) return placeholder;
        return StreamBuilder<CallState>(
          stream: joined.state.valueStream,
          initialData: joined.state.value,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final them = state?.otherParticipants.firstOrNull;
            final me = state?.localParticipant;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (them != null && them.isVideoEnabled)
                  StreamVideoRenderer(
                    call: joined,
                    participant: them,
                    videoTrackType: SfuTrackType.video,
                    placeholderBuilder: (_) => placeholder,
                  )
                else
                  placeholder,
                if (me != null && myCameraOn)
                  PositionedDirectional(
                    top: AppSpacing.md,
                    end: AppSpacing.md,
                    child: SafeArea(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: SizedBox(
                          width: 104,
                          height: 148,
                          child: StreamVideoRenderer(
                            call: joined,
                            participant: me,
                            videoTrackType: SfuTrackType.video,
                            placeholderBuilder: (_) =>
                                ColoredBox(color: colors.surfaceContainerHigh),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
