import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/router/config_router.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_realtime_title.dart';
import '../../../core/widgets/app_error_view.dart';
import '../viewmodel/inbox/inbox_view_model_bloc.dart';
import 'conversation_page.dart';
import '../widgets/inbox_empty_view.dart';
import '../widgets/inbox_list.dart';

/// Chats — the app's home after login (Step 5.1).
///
/// Layout only. Which body to draw comes from the state:
///
/// ```
/// state.data != null, list empty  → InboxEmptyView
/// state.data != null              → InboxList (pull to refresh, load more)
///   + InboxErrorState (has data)  → AppErrorBanner above the list
/// InboxErrorState (no data)       → AppErrorView + "Try again"
/// otherwise                       → spinner
/// ```
///
/// [onOpenProfile] comes from the app layer: the chat feature doesn't import
/// the profile feature (CLAUDE.md: features don't use each other's insides).
class InboxPage extends StatelessWidget {
  const InboxPage({super.key, required this.onOpenProfile});

  final void Function(BuildContext context) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<InboxViewModelBloc>()..add(OnInboxLoadEvent()),
      child: Scaffold(
        appBar: AppBar(
          // "⟳ Connecting…" while live updates are down (Step 5.3).
          title: AppRealtimeTitle(
            title: 'Chats',
            status: getIt<RealtimeService>().status,
          ),
          centerTitle: false,
          actions: [
            Builder(
              builder: (context) => IconButton(
                tooltip: 'My profile',
                onPressed: () => onOpenProfile(context),
                icon: const Icon(Icons.account_circle_outlined),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: BlocBuilder<InboxViewModelBloc, InboxViewModelState>(
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType ||
              previous.data != current.data, // InboxLoadedState has ==
          builder: (context, state) {
            final bloc = context.read<InboxViewModelBloc>();
            final data = state.data;

            // Pull-to-refresh AND the banner's "Try again" wait on this.
            // Wait for "finished", not for a new state: an unchanged list is
            // == the old one, so Bloc emits nothing.
            Future<void> refresh() {
              final done = Completer<void>();
              bloc.add(OnInboxLoadEvent(done: done));
              return done.future;
            }

            if (data != null) {
              return Column(
                children: [
                  // A load failed but we still have chats → keep them, and
                  // show a small strip on top until a load works again.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: state is InboxErrorState
                        ? Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: InboxList.maxWidth,
                              ),
                              child: AppErrorBanner(
                                error: state.error,
                                onRetry: refresh,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: refresh,
                      child: data.conversations.isEmpty
                          ? const InboxEmptyView()
                          : InboxList(
                              conversations: data.conversations,
                              myId: data.myId,
                              isLoadingMore: data.isLoadingMore,
                              onLoadMore: () =>
                                  bloc.add(OnInboxLoadMoreEvent()),
                              onOpen: (conversation) async {
                                bloc.add(
                                  OnInboxConversationOpenedEvent(
                                    conversation.id,
                                  ),
                                );
                                await ConfigRouter.pushPageAnimation<void>(
                                  context,
                                  ConversationPage(
                                    conversation: conversation,
                                    myId: data.myId,
                                  ),
                                );
                                // Back: no reload any more — live updates
                                // (5.3) keep the inbox fresh.
                                if (!bloc.isClosed) {
                                  bloc.add(
                                    OnInboxConversationOpenedEvent(null),
                                  );
                                }
                              },
                            ),
                    ),
                  ),
                ],
              );
            }
            if (state is InboxErrorState) {
              return AppErrorView.fromError(state.error, onRetry: refresh);
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
