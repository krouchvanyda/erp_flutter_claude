import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_error_model.dart';
import '../../model/chat_update.dart';
import '../../model/conversation_model.dart';
import '../../model/message_model.dart';
import '../../repository/chat_repository.dart';
import '../../repository/presence_store.dart';

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
///              last message edited → new preview · deleted → re-fetch (5.6)
///              chat created / changed / removed → list updated
///              connection back → reload page 1 (catch-up)
class InboxViewModelBloc
    extends Bloc<InboxViewModelEvent, InboxViewModelState> {
  InboxViewModelBloc(this._repository, {PresenceStore? presence})
    : _presence = presence,
      super(InboxViewModelInitial()) {
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

  /// Online dots for direct chats (5.6). Optional so tests can skip it.
  final PresenceStore? _presence;

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
        (page) {
          emit(
            InboxLoadedState(
              conversations: page.items,
              myId: myId,
              page: page.page,
              hasMore: page.hasMore,
            ),
          );
          _watchPresence(page.items, myId);
        },
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
        _watchPresence(state.data!.conversations, current.myId);
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

      case MessageChanged(:final message):
        await _onLastMessageChanged(emit, message);

      case MessagesRead() || TypingChanged() || ReactionsChanged():
        break; // only the open conversation cares
    }
  }

  /// Direct chats → follow the OTHER person's online status (one request).
  void _watchPresence(List<ConversationModel> list, String? myId) {
    final presence = _presence;
    if (presence == null) return;
    unawaited(
      presence.watch([
        for (final c in list)
          if (c.otherMember(myId) case final other?) other.userId,
      ]),
    );
  }

  /// `message.edit` / `message.delete` in my inbox queue (5.6). Only the
  /// chat's LAST message matters (that's the preview). The order and the
  /// unread count don't change.
  Future<void> _onLastMessageChanged(
    Emitter<InboxViewModelState> emit,
    MessageModel message,
  ) async {
    bool isLast(ConversationModel c) =>
        c.id == message.conversationId && c.lastMessage?.id == message.id;

    final data = state.data!;
    if (!data.conversations.any(isLast)) return; // an older message
    // Edited → the new text. Deleted → "Message deleted" for a moment…
    _emitData(
      emit,
      data.copyWith(
        conversations: [
          for (final c in data.conversations)
            isLast(c) ? c.copyWith(lastMessage: message) : c,
        ],
      ),
    );
    if (!message.deleted) return;

    // …then ask the server which message is the last one now.
    final result = await _repository.loadConversation(message.conversationId);
    final fresh = result.fold((_) => null, (c) => c);
    final now = state.data;
    if (fresh == null || now == null) return;
    _emitData(
      emit,
      now.copyWith(
        conversations: [
          for (final c in now.conversations)
            c.id == fresh.id
                // keep OUR unread count (the 5.3 rule)
                ? fresh.copyWith(unreadCount: c.unreadCount)
                : c,
        ],
      ),
    );
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
    _watchPresence(data.conversations, data.myId); // new chats → their dots
    final current = state;
    emit(
      current is InboxErrorState
          ? InboxErrorState(error: current.error, lastData: data)
          : data,
    );
  }
}
