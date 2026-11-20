import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// What the user picked in the long-press sheet.
sealed class MessageSheetChoice {
  const MessageSheetChoice();
}

final class ReactChoice extends MessageSheetChoice {
  const ReactChoice(this.emoji);
  final String emoji;
}

final class CopyChoice extends MessageSheetChoice {
  const CopyChoice();
}

final class EditChoice extends MessageSheetChoice {
  const EditChoice();
}

final class DeleteChoice extends MessageSheetChoice {
  const DeleteChoice();
}

/// Long-press a bubble:
///
/// ```
///  👍  ❤️  😂  😮  😢  🙏      ← my current ones are highlighted
///  ⧉ Copy                      (text only)
///  ✎ Edit                      (mine · text · < 15 min)
///  👁 Seen by Dara, Jane        (mine)
///  🗑 Delete            (red)   (mine)
/// ```
abstract final class MessageActionsSheet {
  static const List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  static Future<MessageSheetChoice?> show(
    BuildContext context, {
    required Set<String> myEmojis,
    required bool canReact,
    required bool canCopy,
    required bool canEdit,
    required bool canDelete,
    String? seenBy,
  }) {
    return showModalBottomSheet<MessageSheetChoice>(
      context: context,
      showDragHandle: true,
      // taller than the default 9/16 if needed (small phones, big text),
      // and it scrolls instead of overflowing
      isScrollControlled: true,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        Widget row(
          IconData icon,
          String label,
          MessageSheetChoice choice, {
          bool red = false,
        }) => ListTile(
          leading: Icon(icon, color: red ? colors.error : colors.onSurface),
          title: AppLabel(
            text: label,
            fontSize: AppFontSize.value16,
            fontWeight: FontWeight.w600,
            color: red ? colors.error : null,
          ),
          onTap: () => Navigator.of(context).pop(choice),
        );

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canReact)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (final e in emojis)
                          Semantics(
                            button: true,
                            label: 'React $e',
                            child: InkResponse(
                              onTap: () =>
                                  Navigator.of(context).pop(ReactChoice(e)),
                              radius: 28,
                              child: Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: myEmojis.contains(e)
                                      ? colors.primaryContainer
                                      : null,
                                ),
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (canReact) const Divider(),
                if (canCopy)
                  row(Icons.copy_rounded, 'Copy', const CopyChoice()),
                if (canEdit)
                  row(Icons.edit_rounded, 'Edit', const EditChoice()),
                if (seenBy != null)
                  ListTile(
                    leading: Icon(
                      Icons.done_all_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                    title: AppLabel(
                      text: seenBy,
                      fontSize: AppFontSize.value14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                if (canDelete)
                  row(
                    Icons.delete_outline_rounded,
                    'Delete',
                    const DeleteChoice(),
                    red: true,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
