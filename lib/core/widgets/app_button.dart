import 'package:flutter/material.dart';

import '../theme/app_font_size.dart';
import '../theme/app_label.dart';

/// Full-width primary button (from the MVVM template's `AppButton`).
///
/// Shape, height (52) and colors come from `AppTheme.filledButtonTheme`.
/// Adds what a form needs:
/// - [isLoading] → a small spinner replaces the text, taps are ignored
///   (design guide Screen 1.1) — no double submit.
/// - `onPressed: null` → disabled look (38% opacity, from the theme).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : AppLabel(
            text: text,
            fontSize: AppFontSize.value14,
            fontWeight: FontWeight.w600,
          );

    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading ? null : icon,
      label: child,
    );
  }
}
