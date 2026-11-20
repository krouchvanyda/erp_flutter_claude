import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/network_error_model.dart';
import '../model/chat_update.dart';
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
/// Live (5.3): message.send → new bubble (+ markRead) · my own echo replaces
///             its 🕓 bubble · edit / delete → swapped in place ·
///             message.read → ✓✓ · connection back → reload (catch-up)
/// ```
///
/// Not in the template's getIt factory: every page needs ITS conversation
/// id, so the page builds the bloc with `getIt<ChatRepository>()`.
class ConversationViewModelBloc
    extends Bloc<ConversationViewModelEvent, ConversationViewModelState> {
  ConversationViewModelBloc(
    this._repository, {
    required this.conversationId,
    required this.myId,
  }) : super(ConversationViewModelInitial()) {
    on<OnConversationLoadEvent>(_onLoad);
    on<OnConversationLoadOlderEvent>(_onLoadOlder);
    on<OnMessageSendEvent>(_onSend);
    on<OnMessageRetryEvent>(_onRetry);
    on<OnConversationLiveUpdateEvent>(_onLiveUpdate);

    _subscriptions = [
      _repository
          .conversationUpdates(conversationId)
          .listen((u) => add(OnConversationLiveUpdateEvent(u))),
      _repository.reconnected.listen((_) => add(OnConversationLoadEvent())),
    ];
  }

  final ChatRepository _repository;
  final String conversationId;

  /// Mine → right side, ✓ / ✓✓, and my own echo replaces my 🕓 bubble.
  final String? myId;

  late final List<StreamSubscription<Object?>> _subscriptions;

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel(); // page closed → STOMP unsubscribes the topic
    }
    return super.close();
  }

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
  /// Only moves FORWARD (a newer id than the last one we sent).
  void _markRead(MessageModel? newest) {
    if (newest == null) return;
    final marked = int.tryParse(_markedReadId ?? '') ?? -1;
    if (newest.idNumber <= marked) return;
    _markedReadId = newest.id;
    unawaited(_repository.markRead(conversationId, newest.id));
  }

  // ─────────────── Step 5.3: live ───────────────

  void _onLiveUpdate(
    OnConversationLiveUpdateEvent event,
    Emitter<ConversationViewModelState> emit,
  ) {
    final data = state.data;
    if (data == null) return; // the first load brings everything

    switch (event.update) {
      case MessageArrived(:final message):
        if (message.conversationId != conversationId) return;
        if (data.messages.any((m) => m.id == message.id)) return; // have it
        var outgoing = data.outgoing;
        if (message.senderId == myId) {
          // My own message comes back (the echo) — maybe BEFORE the HTTP
          // answer. It replaces the OLDEST 🕓 bubble with the same text, so
          // it never shows twice.
          final echo = outgoing.lastWhereOrNull(
            (o) => !o.failed && o.text == (message.body ?? '').trim(),
          );
          if (echo != null) {
            outgoing = [
              for (final o in outgoing)
                if (o.localId != echo.localId) o,
            ];
          }
        } else {
          _markRead(message); // I'm looking at it → read
        }
        _emitData(
          emit,
          data.copyWith(
            messages: [message, ...data.messages],
            outgoing: outgoing,
          ),
        );

      case MessageChanged(:final message):
        _emitData(
          emit,
          data.copyWith(
            messages: [
              for (final m in data.messages)
                m.id == message.id
                    // edit / delete events have no read receipts → keep ours
                    ? message.copyWith(
                        readByUserIds: m.readByUserIds,
                        reactions: message.reactions.isEmpty
                            ? m.reactions
                            : message.reactions,
                      )
                    : m,
            ],
          ),
        );

      case MessagesRead(:final userId, :final lastReadMessageId):
        if (userId == myId) return; // my own read (another device)
        final upTo = int.tryParse(lastReadMessageId) ?? 0;
        var changed = false;
        final messages = data.messages.map((m) {
          // ✓✓ for messages NOT sent by the reader, up to their read id
          if (m.senderId == userId ||
              m.idNumber > upTo ||
              m.readByUserIds.contains(userId)) {
            return m;
          }
          changed = true;
          return m.copyWith(readByUserIds: {...m.readByUserIds, userId});
        }).toList();
        if (changed) _emitData(emit, data.copyWith(messages: messages));

      case ConversationChanged() || ConversationRemoved():
        break; // the title / members: Step 5.4
    }
  }
}
