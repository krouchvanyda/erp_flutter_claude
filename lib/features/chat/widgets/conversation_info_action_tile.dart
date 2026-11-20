import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// A row like "+ Add members", "⎋ Leave group" (red when [destructive]).
class ConversationInfoActionTile extends StatelessWidget {
  const ConversationInfoActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap; // null → disabled (busy)
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive ? colors.error : colors.primary;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              SizedBox(width: 44, child: Icon(icon, color: color)),
              const SizedBox(width: AppSpacing.md),
              AppLabel(
                text: label,
                fontSize: AppFontSize.value16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
