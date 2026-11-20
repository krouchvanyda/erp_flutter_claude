import 'package:flutter/material.dart';

import '../theme/app_font_size.dart';
import '../theme/app_label.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// "Are you sure?" dialog. Returns `true` only when the user taps confirm.
///
/// ```dart
/// final yes = await AppConfirmDialog.show(
///   context,
///   icon: Icons.logout_rounded,
///   title: 'Log out?',
///   message: 'You will need to sign in again.',
///   confirmText: 'Log out',
///   destructive: true,
/// );
/// ```
///
/// ```
/// ┌──────────────────────────────┐
/// │            ( ⎋ )             │  icon in a soft circle
/// │          Log out?            │  title
/// │ You will need to sign in…    │  message (muted)
/// │ [  Cancel  ] [  Log out   ]  │  two equal buttons, confirm on the right
/// └──────────────────────────────┘
/// ```
///
/// - [destructive] → red confirm button + red icon (logout, delete, leave).
/// - Never wider than [_maxWidth] (tablet).
/// - Tap outside / back button → `false` (same as Cancel).
abstract final class AppConfirmDialog {
  static const double _maxWidth = 400;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String cancelText = 'Cancel',
    IconData? icon,
    bool destructive = false,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        destructive: destructive,
      ),
    );
    return yes ?? false; // dismissed (tap outside / back) = Cancel
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.icon,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Destructive = red; normal = brand.
    final accent = destructive ? colors.error : colors.primary;
    final onAccent = destructive ? colors.onError : colors.onPrimary;
    final soft = destructive ? colors.errorContainer : colors.primaryContainer;

    // The theme makes buttons full-width (login form). In a Row we need them
    // to share the width → override minimumSize, height 48.
    const buttonSize = Size(0, 48);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppConfirmDialog._maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: soft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppLabel(
                text: title,
                fontSize: AppFontSize.value20,
                fontWeight: FontWeight.w700,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppLabel(
                text: message,
                fontSize: AppFontSize.value14,
                color: colors.onSurfaceVariant,
                textAlign: TextAlign.center,
                lineHeight: 1.5,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: buttonSize,
                        shape: shape,
                        foregroundColor: colors.onSurface,
                        // outlineVariant is too close to the dialog colour → a soft grey line.
                        side: BorderSide(
                          color: colors.outline.withValues(alpha: 0.35),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: AppLabel(
                        text: cancelText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        fontSize: AppFontSize.value14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: buttonSize,
                        shape: shape,
                        backgroundColor: accent,
                        foregroundColor: onAccent,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: AppLabel(
                        text: confirmText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        fontSize: AppFontSize.value14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
