import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// A small round on / off button in a call (🎙 Mute, 🔊 Speaker, 🎥, 🔄).
///
/// [highlighted] = "not the normal state" (muted, loudspeaker on, camera
/// off): the circle fills, so you see at a glance what you changed.
class CallToggleButton extends StatelessWidget {
  const CallToggleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
    this.size = 56,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool highlighted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = highlighted
        ? colors.onSurface
        : colors.surfaceContainerHighest.withValues(alpha: 0.85);
    final foreground = highlighted ? colors.surface : colors.onSurface;

    return Semantics(
      button: true,
      toggled: highlighted,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: size,
                  child: Icon(icon, color: foreground, size: size * 0.44),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: AppLabel(
              text: label,
              fontSize: AppFontSize.value12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
