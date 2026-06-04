import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/app_dependencies.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/route_paths.dart';
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

  /// Listener installed on `activeCallListenable` to auto-push the
  /// in-call page when state transitions to connected. Without this,
  /// the cold-start kill→accept path can silently lose the
  /// `_handleAccept` push (it happens while go_router is still
  /// transitioning splash → dashboard, and the pushed route gets
  /// replaced when the redirect lands).
  /// True while go_router is still resolving the cold-start splash
  /// (`/`) — pushing the call page now would be wiped the instant the
  /// splash→dashboard redirect lands (the "call page → dashboard flash →
  /// call page" bug). We defer the push until the router settles on a
  /// real destination. Returns true on any read failure (treat unknown
  /// as not-yet-settled → keep waiting).
  bool _onSplashOrUnknown() {
    try {
      final path = AppDependencies.I.appRouter
          .config
          .routerDelegate
          .currentConfiguration
          .uri
          .path;
      return path.isEmpty || path == RoutePaths.splash;
    } catch (_) {
      return true;
    }
  }

  void _autoPushOnConnected() {
    final call = _signaling?.activeCallListenable.value;
    if (call == null) return;
    if (call.state != CallSignalState.connected) return;
    // Kick off the retry loop. It self-cancels when the page sticks
    // (isMounted=true) OR when the call ends (state != connected)
    // OR after the max attempts run out.
    _ensureCallPagePushedWithRetry(call);
  }

  /// Tracks whether a retry loop is already running for the current
  /// call, so we don't stack overlapping loops if the state listener
  /// fires multiple times (e.g. participant updates emit while
  /// connected).
  String? _activeRetryLoopCallId;

  /// Push the call page repeatedly during the 6 s WATCH WINDOW after
  /// state→connected. On cold-start, go_router's splash → dashboard
  /// `context.go()` REPLACES the route stack — wiping any route we
  /// pushed before the redirect completed. The wipe can happen AFTER
  /// our initial push succeeded (so the simple "already mounted →
  /// done" check exits the loop prematurely, then the wipe happens
  /// later with no one watching).
  ///
  /// To handle that: we KEEP CHECKING for the full 6 s. Each tick:
  ///   * if the call is gone → cancel
  ///   * if the page is mounted → don't push, but DO continue
  ///     watching (in case a later redirect wipes it)
  ///   * if the page is NOT mounted → push it
  void _ensureCallPagePushedWithRetry(ActiveCall call) {
    // Don't stack loops — if one is already running for this call,
    // it'll handle subsequent wipes too.
    if (_activeRetryLoopCallId == call.callId) {
      return;
    }
    _activeRetryLoopCallId = call.callId;

    const maxTicks = 12; // 12 × 500 ms = 6 s watch window
    var tickCount = 0;
    // Has the call page EVER mounted during this watch window? Once it
    // has, a later not-mounted reading means go_router wiped it → re-push
    // is correct. But BEFORE it has ever mounted, a not-mounted reading
    // just means our (single) push is still landing on a busy cold-start
    // engine — re-pushing there stacks a second page (the 2-page bug).
    var everMounted = false;
    // Have we already issued a push that's still pending its first mount?
    var pushPending = false;
    // Bounded poll count while the router is still on the splash, so a
    // genuinely stuck splash can't loop forever (40 × 300 ms = 12 s).
    var splashPolls = 0;
    void tick() {
      // Bail FIRST so we stop even while parked waiting for the splash
      // redirect to settle.
      final current = _signaling?.activeCallListenable.value;
      if (current == null ||
          current.callId != call.callId ||
          current.state != CallSignalState.connected) {
        // ignore: avoid_print
        print('[IncomingCallOverlay] auto-push: cancelling watch loop '
            '(tick $tickCount) — call ${call.callId} no longer '
            'connected (state=${current?.state})');
        _activeRetryLoopCallId = null;
        return;
      }
      // Splash gate: while go_router is still resolving the cold-start
      // splash→dashboard redirect, ANY push lands on a stack that's
      // about to be replaced → it gets wiped and the user sees the
      // dashboard flash before the page re-appears. Park here (polling
      // every 300 ms) WITHOUT burning the post-splash watch budget until
      // the router settles, then push exactly once.
      if (_onSplashOrUnknown() && splashPolls < 40) {
        splashPolls++;
        // ignore: avoid_print
        print('[IncomingCallOverlay] auto-push: router still on splash '
            '(poll $splashPolls) — deferring push for callId=${call.callId}');
        Future.delayed(const Duration(milliseconds: 300), tick);
        return;
      }
      tickCount++;
      final isVideo = call.callType == ChatCallType.video;
      final alreadyMounted = isVideo
          ? VideoCallPage.isMounted
          : VoiceCallPage.isMounted;
      if (alreadyMounted) {
        // The page is up — our pending push (if any) landed.
        everMounted = true;
        pushPending = false;
      } else {
        // Push ONLY when this is the first attempt, or when the page had
        // mounted and then got wiped (go_router redirect). Do NOT push
        // again merely because a prior push hasn't mounted yet — that is
        // what stacked the page twice on a slow cold start.
        final shouldPush = (!pushPending && !everMounted) || everMounted;
        if (shouldPush) {
          final navigator = AppRouter.rootNavigatorKey.currentState;
          if (navigator != null) {
            // ignore: avoid_print
            print('[IncomingCallOverlay] auto-push tick $tickCount/$maxTicks '
                '· pushing ${isVideo ? "VideoCallPage" : "VoiceCallPage"} '
                'for callId=${call.callId} '
                '(${everMounted ? "page was wiped — re-pushing" : "first push"})');
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => isVideo
                    ? VideoCallPage(conversationId: call.conversationId)
                    : VoiceCallPage(conversationId: call.conversationId),
                fullscreenDialog: true,
              ),
            );
            pushPending = true;
            everMounted = false; // wait for THIS push to mount
          }
        }
      }
      // Continue watching even if mounted — a later redirect could
      // still wipe the page. Stop only after the full watch window.
      if (tickCount < maxTicks) {
        Future.delayed(const Duration(milliseconds: 500), tick);
      } else {
        // ignore: avoid_print
        print('[IncomingCallOverlay] auto-push: watch window closed '
            '($maxTicks × 500 ms) for callId=${call.callId} · '
            'finalMounted=$alreadyMounted');
        _activeRetryLoopCallId = null;
      }
    }
    tick();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolve via GetIt lazily — the service is registered after
    // configureDependencies() in main.dart, so the very first build
    // could fall through if we resolved in initState.
    if (_signaling == null) {
      _signaling = AppDependencies.I.callSignalingService;
      _signaling!.activeCallListenable.addListener(_autoPushOnConnected);
    }
  }

  @override
  void dispose() {
    _signaling?.activeCallListenable.removeListener(_autoPushOnConnected);
    super.dispose();
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
                        AppDependencies.I.callSignalingService.rejectIncoming(),
                  ),
                  _BigCircleButton(
                    icon: call.callType == ChatCallType.video
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    label: 'Accept',
                    color: Colors.green.shade600,
                    onTap: () {
                      final signaling = AppDependencies.I.callSignalingService;
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
