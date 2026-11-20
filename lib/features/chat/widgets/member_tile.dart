import 'package:flutter/material.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/chat_enums.dart';
import '../model/member_model.dart';

/// One member on the chat info page.
///
/// ```
/// (VK) You              [Admin]
/// (DS) Dara Sok                   ⊖   ← only when [onRemove] (I'm admin)
/// ```
class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.member,
    required this.isMe,
    this.onRemove,
  });

  final MemberModel member;
  final bool isMe;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          AppAvatar(
            name: member.displayName,
            imageUrl: ApiEndPoint.fileUrl(member.avatarUrl),
            size: 44,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppLabel(
              text: isMe ? 'You' : member.displayName,
              fontSize: AppFontSize.value16,
              fontWeight: FontWeight.w600,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (member.role == MemberRole.admin)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: AppLabel(
                text: 'Admin',
                fontSize: AppFontSize.value11,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove',
              onPressed: onRemove,
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                color: colors.error,
              ),
            ),
        ],
      ),
    );
  }
}
