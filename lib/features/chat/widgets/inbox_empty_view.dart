import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// "No chats yet" — the inbox loaded fine but is empty.
///
/// It's inside a scrollable so pull-to-refresh still works on it.
/// (Step 5.4 adds a "New chat" button here.)
class InboxEmptyView extends StatelessWidget {
  const InboxEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          // fill the screen so the content can be centred
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.forum_outlined,
                      size: 40,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const AppLabel(
                    text: 'No chats yet',
                    fontSize: AppFontSize.value18,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppLabel(
                    text: 'Your conversations will show up here.',
                    fontSize: AppFontSize.value14,
                    color: colors.onSurfaceVariant,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
