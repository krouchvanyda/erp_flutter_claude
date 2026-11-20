import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../model/call_enums.dart';
import '../model/call_peer.dart';
import '../repository/call_media.dart';
import '../viewmodel/call/call_view_model_bloc.dart';
import '../widgets/call_background.dart';
import '../widgets/call_controls.dart';
import '../widgets/call_peer_header.dart';
import '../widgets/call_permission_gate.dart';
import '../widgets/call_status_text.dart';
import '../widgets/call_video_overlay.dart';
import '../widgets/call_video_view.dart';

/// THE call screen, for every phase (Steps 6.1 + 6.2). Layout only.
///
/// ```
/// voice / ringing / ended            video, in call
/// ┌──────────────────────┐   ┌──────────────────────┐
/// │        (JD)          │   │ Jane Doe 01:15 ┌───┐ │
/// │      Jane Doe        │   │                │me │ │
/// │   📞 Voice call      │   │  THEIR CAMERA  └───┘ │
/// │      01:15           │   │                      │
/// │  (🎙 Mute) (🔊)      │   │ (🎙) (🎥) (🔄) (🔊)  │
/// │       (⛔ End)        │   │       (⛔ End)        │
/// └──────────────────────┘   └──────────────────────┘
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
          CallIdleState() => (CallPeer.unknown, CallType.voice),
        };
        final video = type == CallType.video;
        final controls = CallControls(
          state: state,
          // Microphone (+ camera) first, THEN accept.
          onAccept: () async {
            if (await CallPermissionGate.ensure(context, video: video)) {
              bloc.add(OnCallAcceptEvent());
            }
          },
          onDecline: () => bloc.add(OnCallDeclineEvent()),
          onHangUp: () => bloc.add(OnCallHangUpEvent()),
          onToggleMic: () => bloc.add(OnCallToggleMicEvent()),
          onToggleSpeaker: () => bloc.add(OnCallToggleSpeakerEvent()),
          onToggleCamera: () => bloc.add(OnCallToggleCameraEvent()),
          onFlipCamera: () => bloc.add(OnCallFlipCameraEvent()),
        );
        final header = CallPeerHeader(
          peer: peer,
          kind: _kind(peer.isGroup, video),
          kindIcon: video ? Icons.videocam_outlined : Icons.call_outlined,
          status: CallStatusText(state: state),
        );

        final onVideo = state is CallInCallState && video;
        return PopScope(
          // Back must not drop a live call by accident.
          canPop: !state.isActive,
          // Video: always dark around the picture, in light mode too. Set
          // ABOVE the Scaffold, so its text colours follow too.
          child: Theme(
            data: onVideo ? AppTheme.dark() : Theme.of(context),
            child: Scaffold(
              body: onVideo
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CallVideoView(
                          call: getIt<CallMedia>().call,
                          peer: peer,
                          myCameraOn: state.cameraOn,
                        ),
                        CallVideoOverlay(
                          name: peer.name,
                          status: CallStatusText(state: state),
                          controls: controls,
                        ),
                      ],
                    )
                  : CallBackground(
                      child: Column(
                        children: [
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            child: header,
                          ),
                          const Spacer(flex: 2),
                          controls,
                          const SizedBox(height: AppSpacing.xxl),
                        ],
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
