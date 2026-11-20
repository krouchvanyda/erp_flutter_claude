import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../model/call_enums.dart';
import '../viewmodel/call/call_view_model_bloc.dart';
import '../widgets/call_controls.dart';
import '../widgets/call_peer_header.dart';
import '../widgets/call_status_text.dart';

/// THE call screen, for every phase (Step 6.1). Layout only.
///
/// ```
/// ┌──────────────────────┐
/// │        (JD)          │  CallPeerHeader
/// │      Jane Doe        │
/// │   📞 Voice call      │
/// │     Ringing…         │  CallStatusText (or the timer)
/// │                      │
/// │ (⛔ Decline) (📞 Accept)│  CallControls
/// └──────────────────────┘
/// ```
///
/// ONE page from ring to goodbye: Accept doesn't open a new page, it just
/// changes the state. So nothing is unmounted under the user's finger (the
/// old app's "push the call page first, then accept" bug can't happen).
/// It closes itself when the bloc goes back to Idle.
class CallPage extends StatelessWidget {
  const CallPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return BlocConsumer<CallViewModelBloc, CallViewModelState>(
      listenWhen: (previous, current) => current is CallIdleState,
      listener: (context, state) {
        final route = ModalRoute.of(context);
        if (route == null || !route.isActive) return;
        final navigator = Navigator.of(context);
        // on top → pop with its animation; under something → just remove
        route.isCurrent ? navigator.pop() : navigator.removeRoute(route);
      },
      buildWhen: (previous, current) =>
          current is! CallIdleState && previous != current,
      builder: (context, state) {
        final bloc = context.read<CallViewModelBloc>();
        final (peer, type) = switch (state) {
          CallOutgoingState(:final peer, :final type) => (peer, type),
          CallIncomingState(:final peer, :final call) ||
          CallInCallState(:final peer, :final call) => (peer, call.type),
          CallEndedState(:final peer, :final type) => (peer, type),
          CallIdleState() => (null, CallType.voice),
        };
        final video = type == CallType.video;

        return PopScope(
          // Back must not drop a live call by accident.
          canPop: !state.isActive,
          child: Scaffold(
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.primaryContainer, colors.surface],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        const Spacer(),
                        if (peer != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            child: CallPeerHeader(
                              peer: peer,
                              kind: _kind(peer.isGroup, video),
                              kindIcon: video
                                  ? Icons.videocam_outlined
                                  : Icons.call_outlined,
                              status: CallStatusText(state: state),
                            ),
                          ),
                        const Spacer(flex: 2),
                        CallControls(
                          state: state,
                          onAccept: () => bloc.add(OnCallAcceptEvent()),
                          onDecline: () => bloc.add(OnCallDeclineEvent()),
                          onHangUp: () => bloc.add(OnCallHangUpEvent()),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// "Voice call" · "Video call" · "Group voice call" · "Group video call".
  static String _kind(bool group, bool video) {
    final kind = video ? 'video call' : 'voice call';
    return group ? 'Group $kind' : (video ? 'Video call' : 'Voice call');
  }
}
