import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// A big round call button with a label under it (⛔ End, 📞 Accept, …).
///
/// ```
///   ( 📞 )
///   Accept
/// ```
class CallActionButton extends StatelessWidget {
  const CallActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
    this.onPressed,
    this.size = 68,
  });

  final IconData icon;
  final String label;

  /// Background (from the theme: `statusColors.error / success`).
  final Color color;
  final Color onColor;

  /// null → greyed (e.g. Accept while the server answers).
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1 : 0.5,
            child: Material(
              color: color,
              shape: const CircleBorder(),
              elevation: enabled ? 4 : 0,
              shadowColor: color.withValues(alpha: 0.5),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: size,
                  child: Icon(icon, color: onColor, size: size * 0.42),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: AppLabel(
              text: label,
              fontSize: AppFontSize.value14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
