import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart'
    hide CallMember; // ours (model/call_peer.dart) has the same name

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/call_peer.dart';
import 'call_video_tile.dart';

/// The picture of a video call (Steps 6.2 + 6.3c):
///
/// ```
/// 1 other                       2 others        3–4 others
/// ┌──────────────────┐┌─────┐   ┌──────────┐    ┌─────┬─────┐
/// │  THEIR camera    ││ me  │   │  Dara    │    │Dara │Jane │
/// │  (full screen)   │└─────┘   ├──────────┤    ├─────┼─────┤
/// │                  │          │  Jane    │    │Sok  │ +2  │
/// └──────────────────┘          └──────────┘    └─────┴─────┘
/// ```
/// My camera stays small in the top corner (only when it's on). Nobody yet →
/// the call's photo. More than 4 → the first 4 (Stream puts the speaker
/// first).
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

  static const int maxTiles = 4;

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
            final others = state?.otherParticipants ?? const [];
            final me = state?.localParticipant;

            Widget tile(CallParticipantState p, {bool grid = false}) =>
                CallVideoTile(
                  key: ValueKey(p.sessionId),
                  call: joined,
                  participant: p,
                  member: peer.member(p.userId),
                  showName: grid,
                  avatarSize: grid ? 72 : 112,
                );

            final shown = others.take(maxTiles).toList();
            final Widget them = switch (shown.length) {
              0 => placeholder,
              1 => tile(shown.first),
              2 => Column(
                children: [
                  for (final p in shown) Expanded(child: tile(p, grid: true)),
                ],
              ),
              _ => GridView.count(
                crossAxisCount: 2,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: _aspect(context, rows: 2),
                children: [for (final p in shown) tile(p, grid: true)],
              ),
            };

            return Stack(
              fit: StackFit.expand,
              children: [
                them,
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

  /// Width / height of one tile so [rows] rows fill the screen exactly.
  static double _aspect(BuildContext context, {required int rows}) {
    final size = MediaQuery.sizeOf(context);
    return (size.width / 2) / (size.height / rows);
  }
}
