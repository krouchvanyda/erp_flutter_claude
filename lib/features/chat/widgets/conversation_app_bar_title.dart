import 'package:flutter/material.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/conversation_model.dart';

/// `(JD) Jane Doe` in the app bar. Groups also show "5 members".
/// (Online / typing come with real time in Step 5.3.)
class ConversationAppBarTitle extends StatelessWidget {
  const ConversationAppBarTitle({
    super.key,
    required this.conversation,
    required this.myId,
  });

  final ConversationModel conversation;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = conversation.title(myId);
    return Row(
      children: [
        AppAvatar(
          name: title,
          imageUrl: ApiEndPoint.fileUrl(conversation.avatarUrlFor(myId)),
          size: 38,
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLabel(
                text: title,
                fontSize: AppFontSize.value16,
                fontWeight: FontWeight.w700,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (conversation.isGroup)
                AppLabel(
                  text: '${conversation.members.length} members',
                  fontSize: AppFontSize.value12,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
