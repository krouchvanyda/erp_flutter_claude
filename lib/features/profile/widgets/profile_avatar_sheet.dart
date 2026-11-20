import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// What the user chose in the avatar sheet.
enum AvatarAction { camera, gallery, remove }

/// Bottom sheet: Take photo · Choose from gallery · Remove photo.
///
/// ```
/// ┌──────────────────────────────┐
/// │            ────              │  drag handle
/// │  Profile photo               │
/// │  (📷) Take photo             │
/// │  (🖼) Choose from gallery    │
/// │  (🗑) Remove photo           │  red, only if there is a photo
/// └──────────────────────────────┘
/// ```
/// Returns null when dismissed (swipe down / tap outside).
abstract final class ProfileAvatarSheet {
  static Future<AvatarAction?> show(
    BuildContext context, {
    required bool canRemove,
  }) {
    return showModalBottomSheet<AvatarAction>(
      context: context,
      showDragHandle: true,
      // Tablet: don't stretch the sheet across the screen.
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => _Sheet(canRemove: canRemove),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.canRemove});

  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: AppLabel(
                text: 'Profile photo',
                fontSize: AppFontSize.value18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const _Option(
              icon: Icons.photo_camera_outlined,
              text: 'Take photo',
              action: AvatarAction.camera,
            ),
            const _Option(
              icon: Icons.photo_library_outlined,
              text: 'Choose from gallery',
              action: AvatarAction.gallery,
            ),
            if (canRemove)
              _Option(
                icon: Icons.delete_outline_rounded,
                text: 'Remove photo',
                action: AvatarAction.remove,
                color: colors.error,
              ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.text,
    required this.action,
    this.color,
  });

  final IconData icon;
  final String text;
  final AvatarAction action;

  /// null = normal colour; error colour for "Remove".
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color ?? colors.onSurface),
      ),
      title: AppLabel(
        text: text,
        fontSize: AppFontSize.value16,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
