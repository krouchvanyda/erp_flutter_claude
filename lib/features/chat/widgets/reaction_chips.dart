import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../model/reaction_model.dart';

/// The reactions under a bubble: `(😂 2) (❤️ 1)`.
/// Mine are highlighted; tapping a chip adds / removes MY reaction.
class ReactionChips extends StatelessWidget {
  const ReactionChips({
    super.key,
    required this.reactions,
    required this.myId,
    required this.onTap,
  });

  final List<ReactionModel> reactions;
  final String? myId;
  final ValueChanged<String> onTap; // emoji

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // emoji → how many, in first-seen order
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    final mine = {
      for (final r in reactions)
        if (r.userId == myId) r.emoji,
    };

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final MapEntry(key: emoji, value: count) in counts.entries)
          Semantics(
            button: true,
            label: '$emoji $count${mine.contains(emoji) ? ', yours' : ''}',
            child: InkWell(
              onTap: () => onTap(emoji),
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: mine.contains(emoji)
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: mine.contains(emoji)
                        ? colors.primary
                        : colors.surface,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    if (count > 1) ...[
                      const SizedBox(width: 3),
                      AppLabel(
                        text: '$count',
                        fontSize: AppFontSize.value12,
                        fontWeight: FontWeight.w600,
                        color: mine.contains(emoji)
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
