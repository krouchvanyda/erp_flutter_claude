import 'package:flutter/material.dart';

import '../../../core/config/flavor.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// Phone: app icon + app name in one row.
class LoginBrandRow extends StatelessWidget {
  const LoginBrandRow({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(Icons.forum_rounded, color: colors.primary, size: 28),
        ),
        const SizedBox(width: AppSpacing.md),
        AppLabel(
          text: Flavor.current.appName,
          fontSize: AppFontSize.value20,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}
