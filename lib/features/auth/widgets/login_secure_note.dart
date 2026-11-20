import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// A quiet reassurance line under the form.
class LoginSecureNote extends StatelessWidget {
  const LoginSecureNote({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, size: 16, color: muted),
        const SizedBox(width: AppSpacing.xs),
        AppLabel(
          text: 'Secured connection',
          fontSize: AppFontSize.value12,
          color: muted,
        ),
      ],
    );
  }
}
