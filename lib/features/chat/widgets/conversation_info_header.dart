import 'package:flutter/material.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/conversation_model.dart';

/// Big avatar + name (+ ✎ for a group admin) + "Group · 5 members".
class ConversationInfoHeader extends StatelessWidget {
  const ConversationInfoHeader({
    super.key,
    required this.conversation,
    required this.myId,
    this.onRename,
  });

  final ConversationModel conversation;
  final String? myId;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = conversation.title(myId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          AppAvatar(
            name: title,
            imageUrl: ApiEndPoint.fileUrl(conversation.avatarUrlFor(myId)),
            size: 96,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: AppLabel(
                  text: title,
                  fontSize: AppFontSize.value20,
                  fontWeight: FontWeight.w700,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onRename != null)
                IconButton(
                  tooltip: 'Rename',
                  onPressed: onRename,
                  icon: Icon(Icons.edit_rounded, color: colors.primary),
                ),
            ],
          ),
          AppLabel(
            text: conversation.isGroup
                ? 'Group · ${conversation.members.length} members'
                : 'Direct chat',
            fontSize: AppFontSize.value14,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
