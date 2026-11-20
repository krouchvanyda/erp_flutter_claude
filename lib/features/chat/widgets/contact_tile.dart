import 'package:flutter/material.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/contact_model.dart';

/// One person in the member picker.
///
/// ```
/// (DS) Dara Sok                 ◯ / ✓   ← the circle only when [selectable]
///      dara.sok@company.com
/// ```
class ContactTile extends StatelessWidget {
  const ContactTile({
    super.key,
    required this.contact,
    required this.onTap,
    this.selectable = false,
    this.selected = false,
  });

  final ContactModel contact;
  final VoidCallback? onTap;
  final bool selectable;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            AppAvatar(
              name: contact.displayName,
              imageUrl: ApiEndPoint.fileUrl(contact.avatarUrl),
              size: 44,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(
                    text: contact.displayName,
                    fontSize: AppFontSize.value16,
                    fontWeight: FontWeight.w600,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppLabel(
                    text: contact.email,
                    fontSize: AppFontSize.value12,
                    color: colors.onSurfaceVariant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (selectable)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(selected),
                  size: 26,
                  color: selected ? colors.primary : colors.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
