import 'package:flutter/material.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/conversation_model.dart';

/// `(JD) Jane Doe` in the app bar. The second line:
///
/// ```
/// someone typing  → "typing…" / "Dara is typing…"   (primary colour, 5.6)
/// else, a group   → "5 members"
/// ```
class ConversationAppBarTitle extends StatelessWidget {
  const ConversationAppBarTitle({
    super.key,
    required this.conversation,
    required this.myId,
    this.typingNames = const [],
  });

  final ConversationModel conversation;
  final String? myId;

  /// Names of the people typing now (never me).
  final List<String> typingNames;

  /// The "typing" line. In a direct chat the name is already the title.
  ///
  /// ```
  /// direct            → typing…
  /// group, 1 person   → Dara is typing…
  /// group, 2 people   → Dara and Jane are typing…
  /// group, 3+ people  → 3 people are typing…
  /// ```
  static String? typingLabel(List<String> names, {required bool isGroup}) {
    if (names.isEmpty) return null;
    if (!isGroup) return 'typing…';
    String first(String n) => n.split(' ').first;
    return switch (names.length) {
      1 => '${first(names[0])} is typing…',
      2 => '${first(names[0])} and ${first(names[1])} are typing…',
      final n => '$n people are typing…',
    };
  }

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
              if (typingLabel(typingNames, isGroup: conversation.isGroup)
                  case final typing?)
                AppLabel(
                  text: typing,
                  fontSize: AppFontSize.value12,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else if (conversation.isGroup)
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
