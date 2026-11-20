import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../model/conversation_model.dart';
import 'inbox_tile.dart';

/// The scrolling list of [InboxTile]s + "load more" at the bottom.
///
/// - Calls [onLoadMore] when the user is ~300 px from the end.
/// - [isLoadingMore] → a small spinner as the last row.
/// - Max 720 wide (tablet). Step 5.2 turns wide screens into list + chat.
class InboxList extends StatelessWidget {
  const InboxList({
    super.key,
    required this.conversations,
    required this.myId,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final List<ConversationModel> conversations;
  final String? myId;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  static const double maxWidth = 720; // the page aligns the banner to it
  static const double _loadMoreBefore = 300; // px from the end

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return NotificationListener<ScrollNotification>(
      // Near the end → ask for the next page. The BLoC ignores repeats.
      onNotification: (n) {
        if (n.metrics.extentAfter < _loadMoreBefore) onLoadMore();
        return false; // let RefreshIndicator see it too
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: conversations.length + (isLoadingMore ? 1 : 0),
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: AppSpacing.md + 52 + AppSpacing.md, // under the text
              color: colors.outlineVariant,
            ),
            itemBuilder: (context, index) {
              if (index == conversations.length) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final conversation = conversations[index];
              return InboxTile(
                // key = id → Flutter keeps each row's state when the list
                // reorders (Step 5.3: a new message moves a chat to the top)
                key: ValueKey(conversation.id),
                conversation: conversation,
                myId: myId,
                onTap: null, // Step 5.2 opens the conversation
              );
            },
          ),
        ),
      ),
    );
  }
}
