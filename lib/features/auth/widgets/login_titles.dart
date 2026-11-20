import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// "Welcome back" + "Sign in to your account".
class LoginTitles extends StatelessWidget {
  const LoginTitles({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLabel(
          text: 'Welcome back',
          fontSize: AppFontSize.value28,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppLabel(
          text: 'Sign in to your account',
          fontSize: AppFontSize.value16,
          color: colors.onSurfaceVariant,
        ),
      ],
    );
  }
}
