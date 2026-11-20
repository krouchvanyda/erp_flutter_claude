import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../viewmodel/inbox_view_model_bloc.dart';
import '../widgets/inbox_empty_view.dart';
import '../widgets/inbox_list.dart';

/// Chats — the app's home after login (Step 5.1).
///
/// Layout only. Which body to draw comes from the state:
///
/// ```
/// state.data != null, list empty  → InboxEmptyView
/// state.data != null              → InboxList (pull to refresh, load more)
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
          title: const AppLabel(
            text: 'Chats',
            fontSize: AppFontSize.value24,
            fontWeight: FontWeight.w700,
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
        body: BlocConsumer<InboxViewModelBloc, InboxViewModelState>(
          // Refresh / load-more failed while the list is on screen → red bar.
          listenWhen: (previous, current) =>
              current is InboxErrorState && current.lastData != null,
          listener: (context, state) {
            if (state is InboxErrorState) {
              AppSnackBar.error(
                context,
                title: state.error.title,
                message: state.error.description,
              );
            }
          },
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType ||
              previous.data != current.data, // InboxLoadedState has ==
          builder: (context, state) {
            final bloc = context.read<InboxViewModelBloc>();
            final data = state.data;

            if (data != null) {
              return RefreshIndicator(
                onRefresh: () {
                  bloc.add(OnInboxLoadEvent());
                  return bloc.stream.firstWhere(
                    (s) => s is InboxLoadedState || s is InboxErrorState,
                  );
                },
                child: data.conversations.isEmpty
                    ? const InboxEmptyView()
                    : InboxList(
                        conversations: data.conversations,
                        myId: data.myId,
                        isLoadingMore: data.isLoadingMore,
                        onLoadMore: () => bloc.add(OnInboxLoadMoreEvent()),
                      ),
              );
            }
            if (state is InboxErrorState) {
              return AppErrorView(
                title: state.error.title,
                message: state.error.description,
                onRetry: () => bloc.add(OnInboxLoadEvent()),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
