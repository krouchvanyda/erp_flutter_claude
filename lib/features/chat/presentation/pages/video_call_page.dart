import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_font_size.dart';
import '../../../../core/theme/app_label.dart';
import '../../data/call_signaling_service.dart';
import '../../data/repositories/conversations_repository.dart';
import '../../entities/call_log.dart';
import '../../entities/conversation.dart';
import '../widgets/chat_avatar.dart';

/// Slice 10.2.2 (UI shell) + Slice 10.2.3 (wire signalling).
///
/// Same shape as [VoiceCallPage] — page mounts, kicks off either an
/// outgoing invite or matches a connected accept, listens to
/// [CallSignalingService.activeCall], and closes when the peer hangs
/// up. Media streams are still placeholders; replacing them with
/// `RTCVideoRenderer` is the next step.
class VideoCallPage extends StatefulWidget {
  const VideoCallPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage>
    with WidgetsBindingObserver {
  bool _muted = false;
  bool _cameraOn = true;
  bool _frontCamera = true;
  bool _speaker = true;
  bool _controlsVisible = true;
  bool _remoteVideoOn = true;
  int _elapsedSeconds = 0;
  Offset _pipPosition = const Offset(16, 80);
  Timer? _hideTimer;
  Timer? _ticker;
  late final CallSignalingService _signaling;
  bool _connected = false;
  String _status = 'Connecting…';

  @override
  void initState() {
    super.initState();
    _signaling = GetIt.I<CallSignalingService>();
    _signaling.activeCallListenable.addListener(_onActiveCallChanged);
    WidgetsBinding.instance.addObserver(this);
    final existing = _signaling.current;
    if (existing != null &&
        existing.conversationId == widget.conversationId &&
        existing.state == CallSignalState.connected) {
      _connected = true;
      _startTicker();
    } else if (existing == null ||
        existing.conversationId != widget.conversationId) {
      // Place a new outgoing video invite.
      _signaling.startOutgoing(
        conversationId: widget.conversationId,
        callType: ChatCallType.video,
      );
      _status = 'Calling…';
    } else {
      _status = 'Ringing…';
    }
    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _signaling.activeCallListenable.removeListener(_onActiveCallChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // GET /chats/calls/{id} — recover canonical call state if STOMP
    // missed a `call.accept` / `call.hangup` while we were
    // backgrounded. No-op when the active call doesn't have a
    // backend id yet.
    if (state == AppLifecycleState.resumed) {
      unawaited(_signaling.reconcileActive());
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _onActiveCallChanged() {
    final call = _signaling.activeCallListenable.value;
    if (!mounted) return;
    if (call == null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
      return;
    }
    setState(() {
      switch (call.state) {
        case CallSignalState.outgoingRinging:
          _status = 'Calling…';
        case CallSignalState.incomingRinging:
          _status = 'Ringing…';
        case CallSignalState.connected:
          _connected = true;
          if (_ticker == null) _startTicker();
        case CallSignalState.ended:
          // Slice 10.2.4 — reflect the reason in the top-bar label so
          // the user sees WHY before the page pops.
          _status = switch (call.endReason) {
            'busy' => 'Busy',
            'declined' => 'Declined',
            _ => 'Call ended',
          };
        case CallSignalState.idle:
          break;
      }
    });
    if (call.state == CallSignalState.ended && call.endReason != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final reason = switch (call.endReason) {
          'busy' => '${call.peerName} is on another call.',
          'declined' => '${call.peerName} declined the call.',
          _ => null,
        };
        if (reason != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reason),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _resetHideTimer();
  }

  Future<void> _endCall() async {
    _hideTimer?.cancel();
    _ticker?.cancel();
    await _signaling.hangup();
  }

  String get _timerLabel {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds ~/ 60) % 60;
    final s = _elapsedSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: StreamBuilder<ChatConversation?>(
          stream: GetIt.I<ConversationsRepository>()
              .watchById(widget.conversationId),
          builder: (context, snap) {
            final conv = snap.data;
            return Stack(
              children: [
                // Remote video (placeholder).
                Positioned.fill(
                  child: _remoteVideoOn
                      ? _RemoteVideoPlaceholder(conversation: conv)
                      : _RemoteOffPlaceholder(conversation: conv),
                ),
                // Top bar.
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _controlsVisible ? 1 : 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          AppLabel(
                            text: 'Video Call',
                            fontSize: AppFontSize.value12,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                          const Spacer(),
                          // Slice 10.2.3 — before the peer accepts we
                          // show the live status (Calling… / Ringing…);
                          // once connected the elapsed-time timer
                          // takes over.
                          AppLabel(
                            text: _connected ? _timerLabel : _status,
                            fontSize: AppFontSize.value13,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Local PiP.
                Positioned(
                  left: _pipPosition.dx,
                  top: _pipPosition.dy,
                  child: Draggable(
                    feedback: _LocalPip(cameraOn: _cameraOn, mirror: _frontCamera, dragging: true),
                    childWhenDragging: const SizedBox(width: 120, height: 160),
                    onDragEnd: (details) {
                      // Clamp to screen bounds — leave 12px margin.
                      final media = MediaQuery.of(context);
                      final maxX = media.size.width - 120 - 12;
                      final maxY = media.size.height - 160 - 12;
                      final clamped = Offset(
                        details.offset.dx.clamp(12.0, maxX),
                        details.offset.dy.clamp(48.0, maxY),
                      );
                      setState(() => _pipPosition = clamped);
                    },
                    child: _LocalPip(cameraOn: _cameraOn, mirror: _frontCamera),
                  ),
                ),
                // Bottom controls.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _controlsVisible ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 48),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xCC000000),
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _CtrlButton(
                              icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                              active: _muted,
                              activeColor: Colors.red,
                              label: 'Mute',
                              onTap: () {
                                setState(() => _muted = !_muted);
                                _resetHideTimer();
                              },
                            ),
                            _CtrlButton(
                              icon: _cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                              active: !_cameraOn,
                              activeColor: Colors.white24,
                              label: 'Camera',
                              onTap: () {
                                setState(() {
                                  _cameraOn = !_cameraOn;
                                  if (!_cameraOn) _remoteVideoOn = true; // simulate
                                });
                                _resetHideTimer();
                              },
                            ),
                            _CtrlButton(
                              icon: Icons.cameraswitch_rounded,
                              active: false,
                              label: 'Flip',
                              onTap: () {
                                setState(() => _frontCamera = !_frontCamera);
                                _resetHideTimer();
                              },
                            ),
                            _CtrlButton(
                              icon: _speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
                              active: _speaker,
                              activeColor: const Color(0xFF6366F1),
                              label: 'Speaker',
                              onTap: () {
                                setState(() => _speaker = !_speaker);
                                _resetHideTimer();
                              },
                            ),
                            _EndCtrl(onTap: _endCall),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RemoteVideoPlaceholder extends StatelessWidget {
  const _RemoteVideoPlaceholder({required this.conversation});
  final ChatConversation? conversation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (conversation != null) ...[
              ChatAvatar(
                name: conversation!.name,
                size: 132,
                // Slice 10.2.10 — show the group photo if one is set.
                avatarFilePath: conversation!.avatarFilePath,
                showStatus: false,
              ),
              const SizedBox(height: 16),
              AppLabel(
                text: conversation!.name,
                fontSize: AppFontSize.value24,
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
              const SizedBox(height: 6),
              AppLabel(
                text: 'Video preview',
                fontSize: AppFontSize.value13,
                color: Colors.white60,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RemoteOffPlaceholder extends StatelessWidget {
  const _RemoteOffPlaceholder({required this.conversation});
  final ChatConversation? conversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (conversation != null)
            ChatAvatar(
              name: conversation!.name,
              size: 96,
              avatarFilePath: conversation!.avatarFilePath,
              showStatus: false,
            ),
          const SizedBox(height: 16),
          const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 28),
          const SizedBox(height: 8),
          AppLabel(
            text: 'Camera off',
            fontSize: AppFontSize.value14,
            color: Colors.white.withValues(alpha: 0.65),
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}

class _LocalPip extends StatelessWidget {
  const _LocalPip({
    required this.cameraOn,
    required this.mirror,
    this.dragging = false,
  });
  final bool cameraOn;
  final bool mirror;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cameraOn ? const Color(0xFF334155) : const Color(0xFF1F2937),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: dragging
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: cameraOn
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.person_rounded, color: Colors.white70, size: 40),
                SizedBox(height: 6),
                AppLabel(
                  text: 'You',
                  fontSize: AppFontSize.value14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
              ],
            )
          : const Icon(Icons.videocam_off_rounded, color: Colors.white38),
    );
    if (mirror) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(-1, 1, 1),
          child: child,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: child,
    );
  }
}

class _CtrlButton extends StatelessWidget {
  const _CtrlButton({
    required this.icon,
    required this.active,
    required this.label,
    required this.onTap,
    this.activeColor,
  });
  final IconData icon;
  final bool active;
  final String label;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? (activeColor ?? Colors.white).withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.18);
    final fg = active ? Colors.white : Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: fg, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 6),
        AppLabel(
          text: label,
          fontSize: AppFontSize.value11,
          color: Colors.white.withValues(alpha: 0.85),
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}

class _EndCtrl extends StatelessWidget {
  const _EndCtrl({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.red.shade600,
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: 64,
              height: 64,
              child: Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 6),
        AppLabel(
          text: 'End',
          fontSize: AppFontSize.value11,
          color: Colors.white.withValues(alpha: 0.85),
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}
