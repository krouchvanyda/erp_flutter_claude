import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_error_model.dart';
import '../../model/chat_update.dart';
import '../../model/conversation_model.dart';
import '../../repository/chat_repository.dart';

part 'inbox_view_model_event.dart';
part 'inbox_view_model_state.dart';

/// The inbox's ViewModel (MVVM-template style).
///
/// First load:  Loading → Loaded(page 1)  or  Error(no data)
/// Refresh:     (no Loading — keep the list) → Loaded(page 1) or Error(+data)
///              (an unchanged list emits nothing; `event.done` still completes)
/// Load more:   Loaded(isLoadingMore) → Loaded(page + 1, items appended)
///              or Error(+data)
/// Live (5.3):  new message → preview + time + unread, moved to the top
///              chat created / changed / removed → list updated
///              connection back → reload page 1 (catch-up)
class InboxViewModelBloc
    extends Bloc<InboxViewModelEvent, InboxViewModelState> {
  InboxViewModelBloc(this._repository) : super(InboxViewModelInitial()) {
    on<OnInboxLoadEvent>(_onLoad);
    on<OnInboxLoadMoreEvent>(_onLoadMore);
    on<OnInboxLiveUpdateEvent>(_onLiveUpdate);
    on<OnInboxConversationOpenedEvent>(_onOpened);

    // Live: the bloc listens itself, and turns each update into an event,
    // so every change still goes through ONE place (the handlers).
    _subscriptions = [
      _repository.inboxUpdates().listen(
        (update) => add(OnInboxLiveUpdateEvent(update)),
      ),
      _repository.reconnected.listen((_) => add(OnInboxLoadEvent())),
    ];
  }

  final ChatRepository _repository;
  late final List<StreamSubscription<Object?>> _subscriptions;

  /// The conversation on screen right now (its messages aren't "unread").
  String? _openConversationId;

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel(); // stop listening → STOMP unsubscribes
    }
    return super.close();
  }

  Future<void> _onLoad(
    OnInboxLoadEvent event,
    Emitter<InboxViewModelState> emit,
  ) async {
    try {
      if (state is InboxLoadingState) return;
      final shown = state.data; // the list on screen (null on the first load)
      if (shown == null) emit(InboxLoadingState());

      final myId = await _repository.myUserId();
      final result = await _repository.loadInbox();
      result.fold(
        (error) => emit(InboxErrorState(error: error, lastData: shown)),
        // Same list as before → == → Bloc emits nothing (that's fine).
        (page) => emit(
          InboxLoadedState(
            conversations: page.items,
            myId: myId,
            page: page.page,
            hasMore: page.hasMore,
          ),
        ),
      );
    } finally {
      // ALWAYS, even on an early return → the refresh spinner always stops.
      if (event.done?.isCompleted == false) event.done!.complete();
    }
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

  // ─────────────── Step 5.3: live ───────────────

  void _onOpened(
    OnInboxConversationOpenedEvent event,
    Emitter<InboxViewModelState> emit,
  ) {
    _openConversationId = event.conversationId;
    final id = event.conversationId;
    final data = state.data;
    if (id == null || data == null) return;
    // Opening it reads it → the badge goes away at once.
    _emitData(
      emit,
      data.copyWith(
        conversations: [
          for (final c in data.conversations)
            c.id == id ? c.copyWith(unreadCount: 0) : c,
        ],
      ),
    );
  }

  Future<void> _onLiveUpdate(
    OnInboxLiveUpdateEvent event,
    Emitter<InboxViewModelState> emit,
  ) async {
    if (state.data == null) return; // the first load brings everything
    switch (event.update) {
      case MessageArrived(:final message):
        var known = state.data!.conversations.firstWhereOrNull(
          (c) => c.id == message.conversationId,
        );
        if (known == null) {
          // A chat we haven't loaded (new, or on a later page) → fetch it.
          final result = await _repository.loadConversation(
            message.conversationId,
          );
          known = result.fold((_) => null, (c) => c);
          if (known == null) return;
        }
        final data = state.data; // read again after the await
        if (data == null) return;
        final mine = message.senderId == data.myId;
        final open = message.conversationId == _openConversationId;
        final current =
            data.conversations.firstWhereOrNull((c) => c.id == known!.id) ??
            known;
        final updated = current.copyWith(
          lastMessage: message,
          lastMessageAt: message.createdAt ?? DateTime.now(),
          unreadCount: mine || open ? 0 : current.unreadCount + 1,
        );
        _emitData(emit, data.copyWith(conversations: _toTop(data, updated)));

      case ConversationChanged(:final conversation):
        final data = state.data!;
        final old = data.conversations.firstWhereOrNull(
          (c) => c.id == conversation.id,
        );
        // The server computes `unreadCount` for the member who made the
        // change, but sends it to EVERYONE → for a chat we already show,
        // keep OUR count.
        final updated = old == null
            ? conversation
            : conversation.copyWith(unreadCount: old.unreadCount);
        _emitData(
          emit,
          data.copyWith(
            conversations: old == null
                ? _toTop(data, updated)
                : [
                    for (final c in data.conversations)
                      c.id == updated.id ? updated : c,
                  ],
          ),
        );

      case ConversationRemoved(:final conversationId):
        final data = state.data!;
        _emitData(
          emit,
          data.copyWith(
            conversations: [
              for (final c in data.conversations)
                if (c.id != conversationId) c,
            ],
          ),
        );

      case MessageChanged() || MessagesRead() || TypingChanged():
        break; // only the open conversation cares
    }
  }

  /// [updated] first, then the rest (without its old copy).
  static List<ConversationModel> _toTop(
    InboxLoadedState data,
    ConversationModel updated,
  ) => [
    updated,
    for (final c in data.conversations)
      if (c.id != updated.id) c,
  ];

  /// Keep the state TYPE (an error banner stays), swap only the data.
  void _emitData(Emitter<InboxViewModelState> emit, InboxLoadedState data) {
    final current = state;
    emit(
      current is InboxErrorState
          ? InboxErrorState(error: current.error, lastData: data)
          : data,
    );
  }
}
