import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';

import '../../data/repositories/conversations_repository.dart';
import '../../entities/conversation.dart';
import '../widgets/chat_avatar.dart';

/// Slice 10.2.1 — Voice Call.
///
/// UI shell only — no real WebRTC. State machine:
///   calling → ringing → connected → ended
/// All controls toggle local state and the timer ticks once connected.
class VoiceCallPage extends StatefulWidget {
  const VoiceCallPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

enum _CallStage { calling, ringing, connected, ended }

class _VoiceCallPageState extends State<VoiceCallPage> {
  _CallStage _stage = _CallStage.calling;
  bool _muted = false;
  bool _speaker = false;
  int _elapsedSeconds = 0;
  Timer? _ticker;
  Timer? _stageTimer;

  @override
  void initState() {
    super.initState();
    _stageTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _stage = _CallStage.ringing);
      _stageTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _stage = _CallStage.connected);
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _elapsedSeconds++);
        });
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stageTimer?.cancel();
    super.dispose();
  }

  void _endCall() {
    _ticker?.cancel();
    _stageTimer?.cancel();
    setState(() => _stage = _CallStage.ended);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    });
  }

  String get _statusLabel {
    switch (_stage) {
      case _CallStage.calling:
        return 'Calling…';
      case _CallStage.ringing:
        return 'Ringing…';
      case _CallStage.connected:
        final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
        final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
        return '$m:$s';
      case _CallStage.ended:
        return 'Call ended';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: StreamBuilder<ChatConversation?>(
        stream: GetIt.I<ConversationsRepository>()
            .watchById(widget.conversationId),
        builder: (context, snap) {
          final conv = snap.data;
          return Stack(
            children: [
              // Background gradient.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0F1117),
                        Color(0xFF1A2035),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Voice Call',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (conv != null) ...[
                      _PulsingAvatar(
                        conversation: conv,
                        active: _stage == _CallStage.calling ||
                            _stage == _CallStage.ringing,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        conv.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                    if (_stage == _CallStage.connected) ...[
                      const SizedBox(height: 20),
                      _Waveform(),
                    ],
                    const Spacer(flex: 2),
                    _ControlsRow(
                      muted: _muted,
                      speaker: _speaker,
                      onMute: () => setState(() => _muted = !_muted),
                      onSpeaker: () => setState(() => _speaker = !_speaker),
                      onKeypad: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Keypad UI would open here.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    _EndButton(onTap: _endCall),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PulsingAvatar extends StatelessWidget {
  const _PulsingAvatar({required this.conversation, required this.active});
  final ChatConversation conversation;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final avatar = conversation.isGroup
        ? GroupAvatarCluster(
            previews: conversation.participantPreviews,
            size: 112,
          )
        : ChatAvatar(
            name: conversation.name,
            size: 112,
            showStatus: false,
          );

    final wrapped = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 2,
            ),
          ),
        ),
        avatar,
      ],
    );

    if (!active) return wrapped;
    return wrapped
        .animate(onPlay: (c) => c.repeat())
        .scaleXY(
          begin: 1,
          end: 1.06,
          duration: 1200.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _Waveform extends StatefulWidget {
  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const int barCount = 20;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 36,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < barCount; i++)
                _bar(i, _ctrl.value),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(int i, double t) {
    final phase = (t + i / barCount) % 1.0;
    final h = 8 + 24 * (1 - (phase * 2 - 1).abs());
    return Container(
      width: 4,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ControlsRow extends StatelessWidget {
  const _ControlsRow({
    required this.muted,
    required this.speaker,
    required this.onMute,
    required this.onSpeaker,
    required this.onKeypad,
  });
  final bool muted;
  final bool speaker;
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback onKeypad;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CircleButton(
          icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          active: muted,
          activeColor: Colors.red,
          label: muted ? 'Muted' : 'Mute',
          onTap: onMute,
        ),
        _CircleButton(
          icon: Icons.volume_up_rounded,
          active: speaker,
          activeColor: const Color(0xFF6366F1),
          label: speaker ? 'Speaker' : 'Earpiece',
          onTap: onSpeaker,
        ),
        _CircleButton(
          icon: Icons.dialpad_rounded,
          active: false,
          label: 'Keypad',
          onTap: onKeypad,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
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
        ? (activeColor ?? Colors.white).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.12);
    final fg = active ? Colors.white : Colors.white.withValues(alpha: 0.9);
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
              width: 64,
              height: 64,
              child: Icon(icon, color: fg, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EndButton extends StatelessWidget {
  const _EndButton({required this.onTap});
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
              width: 72,
              height: 72,
              child: Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'End',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
