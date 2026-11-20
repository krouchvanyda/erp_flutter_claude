import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input_text.dart';

/// 👥 + "Group name" + [Create]. Create is enabled only with a name.
/// Stateful only for its text controller (UI state).
class NewGroupForm extends StatefulWidget {
  const NewGroupForm({
    super.key,
    required this.onCreate,
    required this.isLoading,
  });

  final ValueChanged<String> onCreate;
  final bool isLoading;

  @override
  State<NewGroupForm> createState() => _NewGroupFormState();
}

class _NewGroupFormState extends State<NewGroupForm> {
  final _controller = TextEditingController();
  bool _hasName = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _create() {
    final name = _controller.text.trim();
    if (name.isNotEmpty && !widget.isLoading) widget.onCreate(name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_rounded,
                size: 44,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppInputText(
            controller: _controller,
            label: 'Group name',
            hintText: 'e.g. Team ERP',
            enabled: !widget.isLoading,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onChanged: (v) {
              final has = v.trim().isNotEmpty;
              if (has != _hasName) setState(() => _hasName = has);
            },
            onFieldSubmitted: (_) => _create(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: 'Create group',
            isLoading: widget.isLoading,
            onPressed: _hasName ? _create : null,
          ),
        ],
      ),
    );
  }
}
