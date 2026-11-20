import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snack_bar.dart';

/// Recording a voice message (it replaces the composer while it records).
///
/// ```
/// 🔴 0:07  ▁▃▅▂▆▃▁▂▅          ✕    (➤)
/// ```
/// - Starts as soon as it appears (asks for the microphone the first time).
/// - ✕ → thrown away. ➤ → [onSend] with the file and its length.
/// - Shorter than 1 s → thrown away (a mis-tap). Stops by itself at 10 min.
///
/// Recording is device I/O (like picking a photo) → it lives in the UI.
class ChatVoiceRecorderBar extends StatefulWidget {
  const ChatVoiceRecorderBar({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  final void Function(String path, int seconds) onSend;
  final VoidCallback onCancel;

  static const Duration maxLength = Duration(minutes: 10);

  @override
  State<ChatVoiceRecorderBar> createState() => _ChatVoiceRecorderBarState();
}

class _ChatVoiceRecorderBarState extends State<ChatVoiceRecorderBar> {
  final _recorder = AudioRecorder();
  final _levels = <double>[]; // last ~24 loudness values, 0–1
  StreamSubscription<Amplitude>? _amplitude;
  Timer? _ticker;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        AppSnackBar.warning(
          context,
          title: 'Microphone is off',
          message: 'Allow the microphone in Settings to send voice messages.',
        );
      }
      widget.onCancel();
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      // AAC in .m4a → "audio/mp4", which the server accepts. Mono 64 kbps
      // is plenty for speech (~0.5 MB per minute).
      const RecordConfig(bitRate: 64000, numChannels: 1),
      path: path,
    );
    if (!mounted) return;
    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final elapsed = DateTime.now().difference(_startedAt!);
      if (elapsed >= ChatVoiceRecorderBar.maxLength) _send();
      setState(() => _elapsed = elapsed);
    });
    _amplitude = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((a) {
          // dBFS −60 (quiet) … 0 (loud) → 0 … 1
          final level = ((a.current + 60) / 60).clamp(0.05, 1.0);
          setState(() {
            _levels.add(level);
            if (_levels.length > 24) _levels.removeAt(0);
          });
        });
  }

  Future<void> _send() async {
    if (_done) return;
    _done = true;
    _stopTimers();
    final seconds = _elapsed.inMilliseconds / 1000;
    final path = await _recorder.stop();
    if (path == null || seconds < 1) {
      widget.onCancel(); // a mis-tap
      return;
    }
    widget.onSend(path, seconds.round().clamp(1, 3600));
  }

  Future<void> _cancel() async {
    if (_done) return;
    _done = true;
    _stopTimers();
    await _recorder.cancel(); // deletes the file
    widget.onCancel();
  }

  void _stopTimers() {
    _ticker?.cancel();
    _amplitude?.cancel();
  }

  @override
  void dispose() {
    _stopTimers();
    if (!_done) _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final clock =
        '${_elapsed.inMinutes}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    size: 14,
                    color: colors.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppLabel(
                    text: clock,
                    fontSize: AppFontSize.value14,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (final l in _levels)
                          Container(
                            width: 3,
                            height: 4 + 20 * l,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cancel',
            onPressed: _cancel,
            icon: Icon(Icons.close_rounded, color: colors.error),
          ),
          IconButton.filled(
            tooltip: 'Send voice message',
            onPressed: _send,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
