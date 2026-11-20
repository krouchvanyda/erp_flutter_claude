import 'package:flutter/material.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_style.dart';
import '../../../core/utils/chat_time.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/message_model.dart';

/// One search result: who · when, and the text with the match in **bold**.
///
/// ```
/// (DS) Dara Sok                    12 Nov
///      …see you at the **meet**ing tomorrow
/// ```
class MessageSearchTile extends StatelessWidget {
  const MessageSearchTile({
    super.key,
    required this.message,
    required this.senderName,
    required this.query,
    this.senderAvatarUrl,
  });

  final MessageModel message;
  final String senderName;
  final String? senderAvatarUrl;
  final String query;

  /// [text] split into (part, isMatch) — case-insensitive, every match.
  static List<(String, bool)> split(String text, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [(text, false)];
    final lower = text.toLowerCase();
    final parts = <(String, bool)>[];
    var start = 0;
    while (true) {
      final i = lower.indexOf(q, start);
      if (i < 0) break;
      if (i > start) parts.add((text.substring(start, i), false));
      parts.add((text.substring(i, i + q.length), true));
      start = i + q.length;
    }
    if (start < text.length) parts.add((text.substring(start), false));
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = message.createdAt;
    final normal = AppTextStyle.build(
      fontSize: AppFontSize.value14,
      color: colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            name: senderName,
            imageUrl: ApiEndPoint.fileUrl(senderAvatarUrl),
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppLabel(
                        text: senderName,
                        fontSize: AppFontSize.value14,
                        fontWeight: FontWeight.w600,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (time != null)
                      AppLabel(
                        text: ChatTime.inbox(time),
                        fontSize: AppFontSize.value12,
                        color: colors.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      for (final (part, match) in split(
                        message.body ?? '',
                        query,
                      ))
                        TextSpan(
                          text: part,
                          style: match
                              ? normal.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                  backgroundColor: colors.primaryContainer,
                                )
                              : normal,
                        ),
                    ],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
