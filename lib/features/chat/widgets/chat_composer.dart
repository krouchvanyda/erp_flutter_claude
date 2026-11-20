import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_input_text.dart';
import '../model/chat_enums.dart';
import 'chat_attach_sheet.dart';
import 'chat_voice_recorder_bar.dart';

/// The bottom of a conversation.
///
/// ```
/// (📎) ┌ Message… ─────────────┐  (🎤)     ← empty: 🎤 records a voice note
/// (📎) ┌ Hello ────────────────┐  (➤)      ← typing: ➤ sends the text
/// 🔴 0:07 ▁▃▅▂▆        ✕  (➤)              ← recording (ChatVoiceRecorderBar)
/// ```
/// - The text box grows up to 5 lines, then scrolls.
/// - After ➤ the box is cleared at once (the bubble shows 🕓 while sending).
///
/// Stateful only for UI state (the text, "recording?").
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.onAttach,
    required this.onVoice,
    this.onTextChanged,
    this.enabled = true,
  });

  final ValueChanged<String> onSend;

  /// A photo / PDF that passed the size + type checks.
  final void Function(MessageType type, String path) onAttach;

  /// A finished voice note.
  final void Function(String path, int seconds) onVoice;

  /// Every change of the text box (for "typing…", 5.6).
  final ValueChanged<String>? onTextChanged;
  final bool enabled;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;
  bool _recording = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onTextChanged?.call(value);
    final hasText = value.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  Future<void> _attach() async {
    final picked = await ChatAttachSheet.pick(context);
    if (picked != null && mounted) widget.onAttach(picked.type, picked.path);
  }

  @override
  Widget build(BuildContext context) {
    if (_recording) {
      return ChatVoiceRecorderBar(
        onSend: (path, seconds) {
          setState(() => _recording = false);
          widget.onVoice(path, seconds);
        },
        onCancel: () {
          if (mounted) setState(() => _recording = false);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: IconButton(
              tooltip: 'Attach',
              onPressed: widget.enabled ? _attach : null,
              icon: const Icon(Icons.attach_file_rounded),
            ),
          ),
          Expanded(
            child: AppInputText(
              controller: _controller,
              hintText: 'Message…',
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: _onChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: _hasText
                  ? IconButton.filled(
                      key: const ValueKey('send'),
                      tooltip: 'Send',
                      onPressed: widget.enabled ? _send : null,
                      iconSize: 22,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.send_rounded),
                    )
                  : IconButton.filled(
                      key: const ValueKey('mic'),
                      tooltip: 'Record a voice message',
                      onPressed: widget.enabled
                          ? () => setState(() => _recording = true)
                          : null,
                      iconSize: 22,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.mic_rounded),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
