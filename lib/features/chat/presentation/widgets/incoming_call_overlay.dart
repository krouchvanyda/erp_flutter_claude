import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../data/call_signaling_service.dart';
import '../../entities/call_log.dart';
import '../pages/video_call_page.dart';
import '../pages/voice_call_page.dart';

/// Slice 10.2.3 — root-level overlay that listens to
/// [CallSignalingService.activeCall] and shows a full-screen incoming-
/// call sheet the moment a peer fires `call.invite`. Sits inside
/// [MaterialApp.builder] so it can paint over every route (including
/// modal sheets) regardless of where the user is when the call lands.
class IncomingCallOverlay extends StatefulWidget {
  const IncomingCallOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay> {
  CallSignalingService? _signaling;
  String? _displayedCallId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolve via GetIt lazily — the service is registered after
    // configureDependencies() in main.dart, so the very first build
    // could fall through if we resolved in initState.
    _signaling ??= GetIt.I<CallSignalingService>();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<ActiveCall?>(
          valueListenable: _signaling!.activeCallListenable,
          builder: (context, call, _) {
            // Show the full-screen incoming sheet only for calls that
            // landed from a peer and are still in the ringing state.
            // Outgoing-ringing / connected / ended states are handled
            // by the call page itself.
            final shouldShow = call != null &&
                call.state == CallSignalState.incomingRinging;
            if (shouldShow && call.callId != _displayedCallId) {
              _displayedCallId = call.callId;
              HapticFeedback.heavyImpact();
            } else if (!shouldShow) {
              _displayedCallId = null;
            }
            if (!shouldShow) return const SizedBox.shrink();
            return _IncomingCallSheet(call: call);
          },
        ),
      ],
    );
  }
}

class _IncomingCallSheet extends StatelessWidget {
  const _IncomingCallSheet({required this.call});
  final ActiveCall call;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                call.callType == ChatCallType.video
                    ? 'Incoming video call'
                    : 'Incoming voice call',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initialsFor(call.peerName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 40,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                call.peerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ringing…',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(flex: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BigCircleButton(
                    icon: Icons.call_end_rounded,
                    label: 'Decline',
                    color: Colors.red.shade600,
                    onTap: () =>
                        GetIt.I<CallSignalingService>().rejectIncoming(),
                  ),
                  _BigCircleButton(
                    icon: call.callType == ChatCallType.video
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    label: 'Accept',
                    color: Colors.green.shade600,
                    onTap: () async {
                      final signaling = GetIt.I<CallSignalingService>();
                      await signaling.acceptIncoming();
                      if (!context.mounted) return;
                      final navigator = Navigator.of(
                        context,
                        rootNavigator: true,
                      );
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => call.callType == ChatCallType.video
                              ? VideoCallPage(
                                  conversationId: call.conversationId)
                              : VoiceCallPage(
                                  conversationId: call.conversationId),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  static String _initialsFor(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _BigCircleButton extends StatelessWidget {
  const _BigCircleButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 8,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
