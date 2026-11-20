import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/network_error_model.dart';
import '../model/conversation_model.dart';
import '../repository/chat_repository.dart';

part 'inbox_view_model_event.dart';
part 'inbox_view_model_state.dart';

/// The inbox's ViewModel (MVVM-template style).
///
/// First load:  Loading → Loaded(page 1)  or  Error(no data)
/// Refresh:     (no Loading — keep the list) → Loaded(page 1) or Error(+data)
/// Load more:   Loaded(isLoadingMore) → Loaded(page + 1, items appended)
///              or Error(+data)
class InboxViewModelBloc
    extends Bloc<InboxViewModelEvent, InboxViewModelState> {
  InboxViewModelBloc(this._repository) : super(InboxViewModelInitial()) {
    on<OnInboxLoadEvent>(_onLoad);
    on<OnInboxLoadMoreEvent>(_onLoadMore);
  }

  final ChatRepository _repository;

  Future<void> _onLoad(
    OnInboxLoadEvent event,
    Emitter<InboxViewModelState> emit,
  ) async {
    if (state is InboxLoadingState) return;
    final shown = state.data; // the list on screen (null on the first load)
    if (shown == null) emit(InboxLoadingState());

    final myId = await _repository.myUserId();
    final result = await _repository.loadInbox();
    result.fold(
      (error) => emit(InboxErrorState(error: error, lastData: shown)),
      (page) => emit(
        InboxLoadedState(
          conversations: page.items,
          myId: myId,
          page: page.page,
          hasMore: page.hasMore,
        ),
      ),
    );
  }

  Future<void> _onLoadMore(
    OnInboxLoadMoreEvent event,
    Emitter<InboxViewModelState> emit,
  ) async {
    final current = state;
    // Only from a calm Loaded state, and only if there IS a next page.
    if (current is! InboxLoadedState ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true)); // spinner at the bottom

    final result = await _repository.loadInbox(page: current.page + 1);
    result.fold(
      (error) => emit(InboxErrorState(error: error, lastData: current)),
      (page) {
        // A new message can move a chat to the top, which shifts the pages
        // → the same chat could come twice. Keep each id once.
        final seen = current.conversations.map((c) => c.id).toSet();
        emit(
          current.copyWith(
            conversations: [
              ...current.conversations,
              ...page.items.where((c) => seen.add(c.id)),
            ],
            page: page.page,
            hasMore: page.hasMore,
            isLoadingMore: false,
          ),
        );
      },
    );
  }
}
