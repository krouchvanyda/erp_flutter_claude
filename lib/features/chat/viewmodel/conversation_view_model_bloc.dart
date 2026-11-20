import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/network_error_model.dart';
import '../model/message_model.dart';
import '../model/outgoing_message.dart';
import '../repository/chat_repository.dart';

part 'conversation_view_model_event.dart';
part 'conversation_view_model_state.dart';

/// One conversation's ViewModel (Step 5.2).
///
/// ```
/// Load:       Loading → Loaded(page 1) → markRead(newest)   or Error
/// LoadOlder:  Loaded(isLoadingOlder) → Loaded(older appended) or Error(+data)
/// Send:       + outgoing 🕓 → server OK: outgoing → messages ✓
///                           → server fail: outgoing.failed ⚠
/// Retry:      failed ⚠ → 🕓 → (same as Send)
/// ```
///
/// Not in the template's getIt factory: every page needs ITS conversation
/// id, so the page builds the bloc with `getIt<ChatRepository>()`.
class ConversationViewModelBloc
    extends Bloc<ConversationViewModelEvent, ConversationViewModelState> {
  ConversationViewModelBloc(this._repository, {required this.conversationId})
    : super(ConversationViewModelInitial()) {
    on<OnConversationLoadEvent>(_onLoad);
    on<OnConversationLoadOlderEvent>(_onLoadOlder);
    on<OnMessageSendEvent>(_onSend);
    on<OnMessageRetryEvent>(_onRetry);
  }

  final ChatRepository _repository;
  final String conversationId;

  /// The newest id we already sent to `/read` → don't send it twice.
  String? _markedReadId;

  /// For local ids: "local-1", "local-2", …
  int _localSeq = 0;

  Future<void> _onLoad(
    OnConversationLoadEvent event,
    Emitter<ConversationViewModelState> emit,
  ) async {
    try {
      if (state is ConversationLoadingState) return;
      if (state.data == null) emit(ConversationLoadingState());

      final result = await _repository.loadMessages(conversationId);
      // Read the state AGAIN after the await: the user may have sent a
      // message while we waited (handlers run at the same time).
      final current = state.data;
      result.fold(
        (error) =>
            emit(ConversationErrorState(error: error, lastData: current)),
        (page) {
          emit(
            ConversationLoadedState(
              messages: page.items,
              outgoing: current?.outgoing ?? const [],
              page: page.page,
              hasMore: page.hasMore,
            ),
          );
          _markRead(page.items.firstOrNull);
        },
      );
    } finally {
      if (event.done?.isCompleted == false) event.done!.complete();
    }
  }

  Future<void> _onLoadOlder(
    OnConversationLoadOlderEvent event,
    Emitter<ConversationViewModelState> emit,
  ) async {
    final start = state;
    // Same 3 guards as the inbox: the scroll listener fires on every pixel.
    if (start is! ConversationLoadedState ||
        !start.hasMore ||
        start.isLoadingOlder) {
      return;
    }
    emit(start.copyWith(isLoadingOlder: true));

    final result = await _repository.loadMessages(
      conversationId,
      page: start.page + 1,
    );
    final current = state.data ?? start; // sends may have changed it
    result.fold(
      (error) => emit(
        ConversationErrorState(
          error: error,
          lastData: current.copyWith(isLoadingOlder: false),
        ),
      ),
      (page) {
        // A message sent since page 1 shifts every page by one → the
        // oldest one we have can come again. Keep each id once.
        final seen = current.messages.map((m) => m.id).toSet();
        emit(
          current.copyWith(
            messages: [
              ...current.messages,
              ...page.items.where((m) => seen.add(m.id)),
            ],
            page: page.page,
            hasMore: page.hasMore,
            isLoadingOlder: false,
          ),
        );
      },
    );
  }

  Future<void> _onSend(
    OnMessageSendEvent event,
    Emitter<ConversationViewModelState> emit,
  ) async {
    final text = event.text.trim();
    final data = state.data;
    if (text.isEmpty || data == null) return;

    final local = OutgoingMessage(
      localId: 'local-${++_localSeq}',
      text: text,
      createdAt: DateTime.now(),
    );
    // Show it AT ONCE (optimistic) — the user never waits to see their text.
    _emitData(emit, data.copyWith(outgoing: [local, ...data.outgoing]));
    await _deliver(local, emit);
  }

  Future<void> _onRetry(
    OnMessageRetryEvent event,
    Emitter<ConversationViewModelState> emit,
  ) async {
    final data = state.data;
    final failed = data?.outgoing.firstWhereOrNull(
      (o) => o.localId == event.localId && o.failed,
    );
    if (data == null || failed == null) return; // gone, or already retrying

    final retry = failed.copyWith(failed: false); // ⚠ → 🕓
    _emitData(emit, data.copyWith(outgoing: _replace(data.outgoing, retry)));
    await _deliver(retry, emit);
  }

  /// Sends [local] and swaps its bubble for the server's answer.
  Future<void> _deliver(
    OutgoingMessage local,
    Emitter<ConversationViewModelState> emit,
  ) async {
    final result = await _repository.sendText(conversationId, local.text);
    final data = state.data; // fresh: other events may have run meanwhile
    if (data == null) return;

    result.fold(
      (_) => _emitData(
        emit,
        data.copyWith(
          outgoing: _replace(data.outgoing, local.copyWith(failed: true)),
        ),
      ),
      (sent) => _emitData(
        emit,
        data.copyWith(
          outgoing: [
            for (final o in data.outgoing)
              if (o.localId != local.localId) o,
          ],
          // newest first; drop it if a reload already brought it
          messages: [
            sent,
            for (final m in data.messages)
              if (m.id != sent.id) m,
          ],
        ),
      ),
    );
  }

  /// A send must not hide a load error (the banner stays), so keep the
  /// current state TYPE and only swap the data.
  void _emitData(
    Emitter<ConversationViewModelState> emit,
    ConversationLoadedState data,
  ) {
    final current = state;
    emit(
      current is ConversationErrorState
          ? ConversationErrorState(error: current.error, lastData: data)
          : data,
    );
  }

  static List<OutgoingMessage> _replace(
    List<OutgoingMessage> list,
    OutgoingMessage updated,
  ) => [for (final o in list) o.localId == updated.localId ? updated : o];

  /// Best effort, not awaited: a failed "read" must never block the chat.
  void _markRead(MessageModel? newest) {
    if (newest == null || newest.id == _markedReadId) return;
    _markedReadId = newest.id;
    unawaited(_repository.markRead(conversationId, newest.id));
  }
}
