import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_font_size.dart';
import '../../../../core/theme/app_label.dart';
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
              // Slice 10.2.9 — surface "Incoming group voice/video
              // call" for group calls so the recipient knows it's not
              // a 1:1 invite.
              AppLabel(
                text: _typeLabel(call),
                fontSize: AppFontSize.value13,
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
              const Spacer(),
              _IncomingAvatar(call: call),
              const SizedBox(height: 20),
              // For groups the title is the GROUP name (e.g. "TEST01").
              // For direct calls it stays the caller's name.
              AppLabel(
                text: call.isGroup
                    ? (call.conversationName ?? 'Group call')
                    : call.peerName,
                fontSize: AppFontSize.value25,
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Group calls add the caller as a subtitle so the
              // recipient knows WHO started the call.
              AppLabel(
                text: call.isGroup
                    ? '${call.peerName} is calling…'
                    : 'Ringing…',
                fontSize: AppFontSize.value16,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
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
                    onTap: () {
                      final signaling = GetIt.I<CallSignalingService>();
                      // Slice 10.2.9 — push via the root navigator's
                      // GlobalKey, NOT `Navigator.of(context)`. The
                      // overlay is mounted via `MaterialApp.builder` so
                      // the GoRouter's Navigator is a SIBLING (inside
                      // `child` in the Stack), not an ancestor of this
                      // sheet — `Navigator.of(context)` would walk up
                      // and find no Navigator at all, silently dropping
                      // the push. That was the "accept just closes" bug
                      // that survived Slice 10.2.8.
                      final navigator = AppRouter.rootNavigatorKey.currentState;
                      if (navigator == null) {
                        // Should never happen in practice — the router
                        // owns the key for the whole app lifetime — but
                        // bail rather than crash if the gate's somehow
                        // not yet mounted.
                        return;
                      }
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
                      // Fire-and-forget — the call page subscribes to
                      // the service and reacts to the connected state
                      // transition on its own.
                      signaling.acceptIncoming();
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

  /// Slice 10.2.9 — top-bar label distinguishing group from direct
  /// incoming calls.
  static String _typeLabel(ActiveCall call) {
    final isVideo = call.callType == ChatCallType.video;
    if (call.isGroup) {
      return isVideo ? 'Incoming group video call' : 'Incoming group voice call';
    }
    return isVideo ? 'Incoming video call' : 'Incoming voice call';
  }
}

/// Slice 10.2.11 — incoming-sheet hero avatar. Prefers a user-set photo
/// (groups: Slice 10.3.3 / direct: Slice 10.3.5) when present; falls
/// back to a group icon for groups, or caller initials for direct
/// calls.
class _IncomingAvatar extends StatelessWidget {
  const _IncomingAvatar({required this.call});
  final ActiveCall call;

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        (call.conversationAvatarFilePath ?? '').isNotEmpty;
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 2,
        ),
        image: hasPhoto
            ? DecorationImage(
                image: FileImage(File(call.conversationAvatarFilePath!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : (call.isGroup
              ? const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 56,
                )
              : AppLabel(
                  text: _initialsFor(call.peerName),
                  fontSize: AppFontSize.value40,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                )),
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
        AppLabel(
          text: label,
          fontSize: AppFontSize.value13,
          color: Colors.white.withValues(alpha: 0.85),
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}
