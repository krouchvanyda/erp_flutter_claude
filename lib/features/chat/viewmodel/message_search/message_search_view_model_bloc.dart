import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_error_model.dart';
import '../../model/message_model.dart';
import '../../repository/chat_repository.dart';

part 'message_search_view_model_event.dart';
part 'message_search_view_model_state.dart';

/// Search inside ONE conversation (Step 5.6).
///
/// ```
/// type "me" "mee" "meet" ──(wait 350 ms after the LAST key)──► ONE request "meet"
/// an older answer arrives late ──► thrown away (it's for an old query)
/// scroll near the end ──► next page
/// ```
class MessageSearchViewModelBloc
    extends Bloc<MessageSearchViewModelEvent, MessageSearchViewModelState> {
  MessageSearchViewModelBloc(
    this._repository, {
    required this.conversationId,
    this.debounce = const Duration(milliseconds: 350),
  }) : super(const MessageSearchInitial()) {
    on<OnSearchQueryChangedEvent>(_onChanged);
    on<OnSearchRunEvent>(_onRun);
    on<OnSearchLoadMoreEvent>(_onLoadMore);
  }

  final ChatRepository _repository;
  final String conversationId;
  final Duration debounce;

  Timer? _timer;

  /// The latest text → answers for any other text are stale.
  String _latest = '';

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  void _onChanged(
    OnSearchQueryChangedEvent event,
    Emitter<MessageSearchViewModelState> emit,
  ) {
    final query = event.query.trim();
    _latest = query;
    _timer?.cancel();
    if (query.isEmpty) {
      emit(const MessageSearchInitial());
      return;
    }
    _timer = Timer(debounce, () {
      if (!isClosed) add(OnSearchRunEvent(query));
    });
  }

  Future<void> _onRun(
    OnSearchRunEvent event,
    Emitter<MessageSearchViewModelState> emit,
  ) async {
    if (event.query != _latest) return; // typed more meanwhile
    emit(MessageSearchLoadingState(event.query));
    final result = await _repository.searchMessages(
      conversationId,
      event.query,
    );
    if (event.query != _latest) return; // stale answer → drop it
    result.fold(
      (error) => emit(MessageSearchErrorState(event.query, error)),
      (page) => emit(
        MessageSearchLoadedState(
          event.query,
          results: page.items,
          page: page.page,
          hasMore: page.hasMore,
        ),
      ),
    );
  }

  Future<void> _onLoadMore(
    OnSearchLoadMoreEvent event,
    Emitter<MessageSearchViewModelState> emit,
  ) async {
    final current = state;
    if (current is! MessageSearchLoadedState ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    final result = await _repository.searchMessages(
      conversationId,
      current.query,
      page: current.page + 1,
    );
    if (current.query != _latest) return;
    result.fold(
      (_) => emit(current.copyWith(isLoadingMore: false)), // keep what we have
      (page) {
        final seen = current.results.map((m) => m.id).toSet();
        emit(
          current.copyWith(
            results: [
              ...current.results,
              ...page.items.where((m) => seen.add(m.id)),
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
