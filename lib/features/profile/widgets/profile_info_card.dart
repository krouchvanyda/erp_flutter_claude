import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import 'profile_info_row.dart';

/// Design guide 9.9 "SectionHeader" + "AppCard" of [ProfileInfoRow]s,
/// with thin dividers between rows.
///
/// ```
/// CONTACT
/// ┌──────────────────────────┐
/// │ ( ✉ ) Email              │
/// │───────────────────────── │
/// │ ( ☎ ) Phone              │
/// └──────────────────────────┘
/// ```
class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({super.key, required this.title, required this.rows});

  final String title;
  final List<ProfileInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: AppLabel(
            text: title.toUpperCase(),
            fontSize: AppFontSize.value12,
            fontWeight: FontWeight.w600,
            color: colors.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, row) in rows.indexed) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: AppSpacing.md + 36 + AppSpacing.md, // under text
                    color: colors.outlineVariant,
                  ),
                row,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
