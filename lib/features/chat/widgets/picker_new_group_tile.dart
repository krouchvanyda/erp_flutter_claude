import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// "👥 New group" — the first row of the new-chat picker.
class PickerNewGroupTile extends StatelessWidget {
  const PickerNewGroupTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.group_add_rounded, color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            AppLabel(
              text: 'New group',
              fontSize: AppFontSize.value16,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
