import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// "No messages yet" — a new conversation. The composer stays below it.
class ConversationEmptyView extends StatelessWidget {
  const ConversationEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.waving_hand_rounded,
                size: 34,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppLabel(
              text: 'No messages yet',
              fontSize: AppFontSize.value18,
              fontWeight: FontWeight.w600,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppLabel(
              text: 'Say hi to start the conversation.',
              fontSize: AppFontSize.value14,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
