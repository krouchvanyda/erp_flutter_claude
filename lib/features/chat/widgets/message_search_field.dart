import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_text_style.dart';

/// The search box IN the app bar (opens with the keyboard up).
/// Stateful only for its text controller (UI state).
class MessageSearchField extends StatefulWidget {
  const MessageSearchField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<MessageSearchField> createState() => _MessageSearchFieldState();
}

class _MessageSearchFieldState extends State<MessageSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: AppTextStyle.build(fontSize: AppFontSize.value16),
      onChanged: (v) {
        widget.onChanged(v);
        setState(() {}); // show / hide ✕
      },
      // no box: it sits in the app bar like a title
      decoration: InputDecoration(
        hintText: 'Search messages',
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintStyle: AppTextStyle.build(
          fontSize: AppFontSize.value16,
          color: colors.onSurfaceVariant,
        ),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}
