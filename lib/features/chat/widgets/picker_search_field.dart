import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_input_text.dart';

/// "🔍 Search people…" at the top of the member picker.
/// Stateful only for its text controller (UI state).
class PickerSearchField extends StatefulWidget {
  const PickerSearchField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<PickerSearchField> createState() => _PickerSearchFieldState();
}

class _PickerSearchFieldState extends State<PickerSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: AppInputText(
        controller: _controller,
        hintText: 'Search by name or email',
        prefixIcon: const Icon(Icons.search_rounded),
        textInputAction: TextInputAction.search,
        onChanged: widget.onChanged,
      ),
    );
  }
}
