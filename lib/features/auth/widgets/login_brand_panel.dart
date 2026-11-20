import 'package:flutter/material.dart';

import '../../../core/config/flavor.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// Wide screens: a calm brand panel in the primary colour.
class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primary,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(
                  Icons.forum_rounded,
                  color: colors.onPrimary,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppLabel(
                text: Flavor.current.appName,
                fontSize: AppFontSize.value32,
                fontWeight: FontWeight.w700,
                color: colors.onPrimary,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppLabel(
                text: 'Chat, voice and video calls —\nyour team, in one place.',
                fontSize: AppFontSize.value16,
                color: colors.onPrimary.withValues(alpha: 0.85),
                lineHeight: 1.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
