import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/chat_time.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/conversation_model.dart';
import '../model/presence_model.dart';
import 'presence_dot.dart';

/// One inbox row.
///
/// ```
/// ┌──┐ Jane Doe                 10:42
/// │JD│ You: See you tomorrow      ③
/// └──┘
/// ```
/// Unread → bold title + preview, primary-coloured time, a count badge.
class InboxTile extends StatelessWidget {
  const InboxTile({
    super.key,
    required this.conversation,
    required this.myId,
    this.onTap,
    this.presence,
  });

  final ConversationModel conversation;
  final String? myId;
  final VoidCallback? onTap;

  /// Online dots (5.6): direct chats show the other person's status.
  final ValueListenable<Map<String, PresenceModel>>? presence;

  /// The preview line. The "You: " / "Dara: " prefix is added HERE and only
  /// here (CLAUDE.md: one place), never stored in the model.
  String _preview() {
    final last = conversation.lastMessage;
    if (last == null) return 'No messages yet';
    final text = last.previewText;
    if (last.senderId == myId) return 'You: $text';
    if (conversation.isGroup) {
      final who = conversation.lastSenderName();
      if (who != null) return '${who.split(' ').first}: $text';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final unread = conversation.unreadCount > 0;
    final title = conversation.title(myId);
    final time = conversation.lastMessageAt ?? conversation.createdAt;
    // direct chat → the other person's dot (a group has no single status)
    final dotFor = presence == null || conversation.isGroup
        ? null
        : conversation.otherMember(myId)?.userId;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppAvatar(
                  name: title,
                  imageUrl: ApiEndPoint.fileUrl(
                    conversation.avatarUrlFor(myId),
                  ),
                  size: 52,
                ),
                if (dotFor != null)
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: PresenceDot(userId: dotFor, presence: presence!),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (conversation.isGroup) ...[
                        Icon(
                          Icons.groups_rounded,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: AppLabel(
                          text: title,
                          fontSize: AppFontSize.value16,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w600,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (time != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        AppLabel(
                          text: ChatTime.inbox(time),
                          fontSize: AppFontSize.value12,
                          fontWeight: unread
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: unread
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: AppLabel(
                          text: _preview(),
                          fontSize: AppFontSize.value14,
                          fontWeight: unread
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: unread
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _UnreadBadge(count: conversation.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ③ — "99+" above 99 so the pill never grows huge.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: AppLabel(
        text: count > 99 ? '99+' : '$count',
        fontSize: AppFontSize.value11,
        fontWeight: FontWeight.w700,
        color: colors.onPrimary,
      ),
    );
  }
}
