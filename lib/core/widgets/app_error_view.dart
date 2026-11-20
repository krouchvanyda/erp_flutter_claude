import 'package:flutter/material.dart';

import '../theme/app_font_size.dart';
import '../theme/app_label.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Full-page "could not load" view with a retry button.
///
/// Use it when a page has NOTHING to show yet (first load failed). When the
/// page already shows data and a refresh fails, use `AppSnackBar` instead.
///
/// ```
///        ( ☁ )
///   No Internet
///   Please check internet connection.
///   [  Try again  ]
/// ```
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 36,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppLabel(
                text: title,
                fontSize: AppFontSize.value18,
                fontWeight: FontWeight.w600,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              AppLabel(
                text: message,
                fontSize: AppFontSize.value14,
                color: colors.onSurfaceVariant,
                textAlign: TextAlign.center,
                lineHeight: 1.5,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                text: 'Try again',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
