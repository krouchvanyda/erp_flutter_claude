import 'package:flutter/material.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/contact_model.dart';

/// The ticked people as a row of small avatars (tap one to untick).
///
/// ```
///  (DS)ⓧ  (JD)ⓧ  (SC)ⓧ
///  Dara   Jane   Sok
/// ```
class SelectedContactsBar extends StatelessWidget {
  const SelectedContactsBar({super.key, required this.selected, this.onRemove});

  final List<ContactModel> selected;

  /// null → read-only (the group name page).
  final ValueChanged<ContactModel>? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: selected.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm + 4),
        itemBuilder: (context, index) {
          final c = selected[index];
          return GestureDetector(
            key: ValueKey(c.id),
            onTap: onRemove == null ? null : () => onRemove!(c),
            child: SizedBox(
              width: 56,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AppAvatar(
                        name: c.displayName,
                        imageUrl: ApiEndPoint.fileUrl(c.avatarUrl),
                        size: 48,
                      ),
                      if (onRemove != null)
                        PositionedDirectional(
                          end: -2,
                          bottom: -2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cancel_rounded,
                              size: 20,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppLabel(
                    text: c.displayName.split(' ').first,
                    fontSize: AppFontSize.value12,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
