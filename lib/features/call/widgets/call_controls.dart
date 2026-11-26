import 'package:flutter/material.dart';

import '../../../core/theme/app_status_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../viewmodel/call/call_view_model_bloc.dart';
import 'call_action_button.dart';
import 'call_toggle_button.dart';

/// The buttons at the bottom, from the state:
///
/// ```
/// Incoming          (⛔ Decline)      (📞 Accept)
/// Outgoing                   (⛔ End)
/// InCall voice      (🎙 Mute) (🔊 Speaker)
///                            (⛔ End)
/// InCall video  (🎙) (🎥) (🔄) (🔊)
///                            (⛔ End)
/// Ended / Idle               (nothing)
/// ```
class CallControls extends StatelessWidget {
  const CallControls({
    super.key,
    required this.state,
    required this.onAccept,
    required this.onDecline,
    required this.onHangUp,
    required this.onToggleMic,
    required this.onToggleSpeaker,
    required this.onToggleCamera,
    required this.onFlipCamera,
  });

  final CallViewModelState state;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onHangUp;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleCamera;
  final VoidCallback onFlipCamera;

  @override
  Widget build(BuildContext context) {
    final status = context.statusColors;
    final end = CallActionButton(
      icon: Icons.call_end_rounded,
      label: state is CallIncomingState ? 'Decline' : 'End',
      color: status.error,
      onColor: status.onError,
      onPressed: state is CallIncomingState ? onDecline : onHangUp,
    );

    final Widget buttons = switch (state) {
      // "Answer" was tapped on the notification (7.4): accepting by itself,
      // only Decline stays (to change your mind).
      CallIncomingState(:final autoAnswer) when autoAnswer => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [end],
      ),
      CallIncomingState(:final accepting, :final call) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          end,
          CallActionButton(
            icon: call.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
            label: 'Accept',
            color: status.success,
            onColor: status.onSuccess,
            onPressed: accepting ? null : onAccept,
          ),
        ],
      ),
      CallInCallState(
        :final call,
        :final micOn,
        :final speakerOn,
        :final cameraOn,
      ) =>
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CallToggleButton(
                  icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                  label: micOn ? 'Mute' : 'Unmute',
                  highlighted: !micOn,
                  onPressed: onToggleMic,
                ),
                if (call.isVideo) ...[
                  CallToggleButton(
                    icon: cameraOn
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    label: 'Camera',
                    highlighted: !cameraOn,
                    onPressed: onToggleCamera,
                  ),
                  CallToggleButton(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Flip',
                    onPressed: cameraOn ? onFlipCamera : null,
                  ),
                ],
                CallToggleButton(
                  icon: speakerOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_down_rounded,
                  label: 'Speaker',
                  highlighted: speakerOn,
                  onPressed: onToggleSpeaker,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            end,
          ],
        ),
      CallOutgoingState() => Center(child: end),
      // keep the height → the header doesn't jump when the buttons go
      CallEndedState() || CallIdleState() => const SizedBox(height: 96),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(state.runtimeType), child: buttons),
      ),
    );
  }
}
