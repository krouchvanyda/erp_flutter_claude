import 'package:flutter/material.dart';

import '../../../core/theme/app_status_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../viewmodel/call/call_view_model_bloc.dart';
import 'call_action_button.dart';

/// The buttons at the bottom, from the state:
///
/// ```
/// Incoming          (⛔ Decline)      (📞 Accept)
/// Outgoing / InCall          (⛔ End)
/// Ended / Idle               (nothing)
/// ```
/// Mute · speaker · camera come with the real audio (Step 6.2).
class CallControls extends StatelessWidget {
  const CallControls({
    super.key,
    required this.state,
    required this.onAccept,
    required this.onDecline,
    required this.onHangUp,
  });

  final CallViewModelState state;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onHangUp;

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
      CallOutgoingState() || CallInCallState() => Center(child: end),
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
