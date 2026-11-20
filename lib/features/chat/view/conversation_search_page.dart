import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_error_view.dart';
import '../model/conversation_model.dart';
import '../repository/chat_repository.dart';
import '../viewmodel/message_search/message_search_view_model_bloc.dart';
import '../widgets/message_search_field.dart';
import '../widgets/message_search_tile.dart';

/// 🔍 in a chat → search its messages (Step 5.6). Layout only.
///
/// ```
/// ┌ ← [Search messages        ✕] ┐
/// │ (DS) Dara Sok          12 Nov │
/// │      …the **meet**ing at 9    │
/// └───────────────────────────────┘
/// ```
/// v1: results only — no "jump to the message" (it may be pages away from
/// what the chat has loaded).
class ConversationSearchPage extends StatelessWidget {
  const ConversationSearchPage({
    super.key,
    required this.conversation,
    required this.myId,
  });

  final ConversationModel conversation;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final membersById = {for (final m in conversation.members) m.userId: m};

    Widget hint(IconData icon, String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            AppLabel(
              text: text,
              fontSize: AppFontSize.value14,
              color: colors.onSurfaceVariant,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    return BlocProvider(
      create: (_) => MessageSearchViewModelBloc(
        getIt<ChatRepository>(),
        conversationId: conversation.id,
      ),
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Builder(
            builder: (context) => MessageSearchField(
              onChanged: (q) => context.read<MessageSearchViewModelBloc>().add(
                OnSearchQueryChangedEvent(q),
              ),
            ),
          ),
        ),
        body:
            BlocBuilder<
              MessageSearchViewModelBloc,
              MessageSearchViewModelState
            >(
              builder: (context, state) {
                final bloc = context.read<MessageSearchViewModelBloc>();
                return switch (state) {
                  MessageSearchInitial() => hint(
                    Icons.search_rounded,
                    'Search in “${conversation.title(myId)}”',
                  ),
                  MessageSearchLoadingState() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  MessageSearchErrorState(:final error, :final query) =>
                    AppErrorView.fromError(
                      error,
                      onRetry: () => bloc.add(OnSearchRunEvent(query)),
                    ),
                  MessageSearchLoadedState(:final results)
                      when results.isEmpty =>
                    hint(Icons.search_off_rounded, 'No messages found'),
                  final MessageSearchLoadedState loaded =>
                    NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.extentAfter < 300) {
                          bloc.add(OnSearchLoadMoreEvent());
                        }
                        return false;
                      },
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: ListView.separated(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount:
                                loaded.results.length +
                                (loaded.isLoadingMore ? 1 : 0),
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              indent: AppSpacing.md + 40 + AppSpacing.md,
                              color: colors.outlineVariant,
                            ),
                            itemBuilder: (context, i) {
                              if (i == loaded.results.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(AppSpacing.md),
                                  child: Center(
                                    child: SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final m = loaded.results[i];
                              final sender = membersById[m.senderId];
                              return MessageSearchTile(
                                key: ValueKey(m.id),
                                message: m,
                                query: loaded.query,
                                senderName: m.senderId == myId
                                    ? 'You'
                                    : (sender?.displayName ?? 'Unknown'),
                                senderAvatarUrl: sender?.avatarUrl,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                };
              },
            ),
      ),
    );
  }
}
