import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input_text.dart';

/// Bottom sheet "Group name" → the new name, or null (cancelled).
///
/// ```dart
/// final name = await ConversationRenameSheet.show(context, current: 'Team');
/// ```
class ConversationRenameSheet extends StatefulWidget {
  const ConversationRenameSheet({super.key, required this.current});

  final String current;

  static Future<String?> show(
    BuildContext context, {
    required String current,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true, // moves up with the keyboard
    showDragHandle: true,
    builder: (_) => ConversationRenameSheet(current: current),
  );

  @override
  State<ConversationRenameSheet> createState() =>
      _ConversationRenameSheetState();
}

class _ConversationRenameSheetState extends State<ConversationRenameSheet> {
  late final _controller = TextEditingController(text: widget.current);
  bool _valid = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppLabel(
                text: 'Group name',
                fontSize: AppFontSize.value18,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: AppSpacing.md),
              AppInputText(
                controller: _controller,
                hintText: 'e.g. Team ERP',
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onChanged: (v) => setState(() => _valid = v.trim().isNotEmpty),
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(text: 'Save', onPressed: _valid ? _save : null),
            ],
          ),
        ),
      ),
    );
  }
}
