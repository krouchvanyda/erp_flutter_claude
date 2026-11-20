import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// Design guide 9.9 "InfoRow": icon · small label · value.
///
/// ```
/// ( ✉ )  Email
///        jane@company.com
/// ```
/// Empty value → a muted "—", so every card keeps the same rows.
class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = value?.trim() ?? '';
    final empty = text.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppLabel(
                  text: label,
                  fontSize: AppFontSize.value12,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                AppLabel(
                  text: empty ? '—' : text,
                  fontSize: AppFontSize.value16,
                  color: empty ? colors.onSurfaceVariant : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
