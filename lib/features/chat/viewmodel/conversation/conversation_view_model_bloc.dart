import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_error_model.dart';
import '../../model/chat_attachment.dart';
import '../../model/chat_enums.dart';
import '../../model/chat_update.dart';
import '../../model/message_model.dart';
import '../../model/outgoing_message.dart';
import '../../model/reaction_model.dart';
import '../../repository/chat_repository.dart';

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
/// Attachment: + outgoing ◔ (upload %) → uploaded → 🕓 → ✓ (5.5)
///             retry skips the upload if it already worked
/// Actions (5.6): edit (composer edit mode) · delete · reactions (optimistic)
///             a failure → ActionFailed (snackbar), the messages stay
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
    on<OnAttachmentSendEvent>(_onSendAttachment);
    on<OnConversationLiveUpdateEvent>(_onLiveUpdate);
    on<OnMessageEditStartEvent>(_onEditStart);
    on<OnMessageEditCancelEvent>(_onEditCancel);
    on<OnMessageEditSubmitEvent>(_onEditSubmit);
    on<OnMessageDeleteEvent>(_onDelete);
    on<OnReactionToggleEvent>(_onReactionToggle);

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

  /// Photo / PDF / voice (Step 5.5): show it at once (my own file), then
  /// upload + send.
  Future<void> _onSendAttachment(
    OnAttachmentSendEvent event,
    Emitter<ConversationViewModelState> emit,
  ) async {
    final data = state.data;
    if (data == null) return;
    final local = OutgoingMessage(
      localId: 'local-${++_localSeq}',
      text: '',
      createdAt: DateTime.now(),
      type: event.type,
      localPath: event.filePath,
      contentType: AttachmentRules.contentTypeFor(event.filePath),
      durationSeconds: event.durationSeconds,
      progress: 0,
    );
    _emitData(emit, data.copyWith(outgoing: [local, ...data.outgoing]));
    await _deliver(local, emit);
  }

  /// Sends [local] and swaps its bubble for the server's answer.
  ///
  /// Text: one request. Attachment: upload (unless a retry already has the
  /// url) → message. Any failure → that bubble ⚠, the text / file kept.
  Future<void> _deliver(
    OutgoingMessage local,
    Emitter<ConversationViewModelState> emit,
  ) async {
    Either<NetworkErrorModel, MessageModel> result;
    if (!local.isAttachment) {
      result = await _repository.sendText(conversationId, local.text);
    } else {
      var current = local;
      if (current.uploadedUrl == null) {
        var shown = 0; // last % drawn → redraw only every 5 %
        final upload = await _repository.uploadAttachment(
          current.localPath!,
          onProgress: (p) {
            final percent = (p * 100).floor();
            if (percent - shown < 5 && percent < 100) return;
            shown = percent;
            _updateOutgoing(emit, current.copyWith(progress: p));
          },
        );
        final uploaded = upload.fold((_) => null, (a) => a);
        if (uploaded == null) {
          _updateOutgoing(
            emit,
            current.copyWith(failed: true, clearProgress: true),
          );
          return;
        }
        current = current.copyWith(
          uploadedUrl: uploaded.url,
          contentType: uploaded.contentType,
          sizeBytes: uploaded.sizeBytes,
          clearProgress: true, // ◔ → 🕓
        );
        _updateOutgoing(emit, current);
      }
      result = await _repository.sendAttachment(
        conversationId,
        type: current.type,
        attachment: ChatAttachmentModel(
          url: current.uploadedUrl!,
          contentType: current.contentType ?? '',
          sizeBytes: current.sizeBytes ?? 0,
        ),
        durationSeconds: current.durationSeconds,
      );
      local = current;
    }

    final data = state.data; // fresh: other events may have run meanwhile
    if (data == null) return;
    result.fold(
      (_) => _updateOutgoing(emit, local.copyWith(failed: true)),
      (sent) => _emitData(
        emit,
        data.copyWith(
          outgoing: [
            for (final o in data.outgoing)
              if (o.localId != local.localId) o,
          ],
          // newest first; drop it if a reload / the echo already brought it
          messages: [
            sent,
            for (final m in data.messages)
              if (m.id != sent.id) m,
          ],
        ),
      ),
    );
  }

  /// Replace one outgoing bubble (progress, uploaded url, failed) — on the
  /// LATEST state, and only if it's still there.
  void _updateOutgoing(
    Emitter<ConversationViewModelState> emit,
    OutgoingMessage updated,
  ) {
    final data = state.data;
    if (data == null || emit.isDone) return;
    if (!data.outgoing.any((o) => o.localId == updated.localId)) return;
    _emitData(emit, data.copyWith(outgoing: _replace(data.outgoing, updated)));
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
          // text → same text; attachment → same uploaded url (5.5)
          final echo = outgoing.lastWhereOrNull(
            (o) =>
                !o.failed &&
                (message.type == MessageType.text
                    ? !o.isAttachment && o.text == (message.body ?? '').trim()
                    : o.uploadedUrl != null &&
                          o.uploadedUrl == message.attachmentUrl),
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
        if (message.deleted) {
          // History leaves deleted messages OUT (`…DeletedAtIsNull`) → we
          // remove it too, so a reload never changes what you see.
          _emitData(emit, _without(data, message.id));
          return;
        }
        _emitData(emit, _replaceMessage(data, message));

      case ReactionsChanged(:final messageId, :final reactions):
        _emitData(emit, _withReactions(data, messageId, reactions));

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

      case ConversationChanged() || ConversationRemoved() || TypingChanged():
        break; // title / members: info bloc (5.4) · typing: typing bloc (5.6)
    }
  }

  // ─────────────── Step 5.6: message actions ───────────────

  /// Editable = mine, TEXT, not deleted, younger than the server's 15 min.
  static const Duration editWindow = Duration(minutes: 15);

  bool canEdit(MessageModel m) =>
      m.senderId == myId &&
      m.type == MessageType.text &&
      !m.deleted &&
      m.createdAt != null &&
      DateTime.now().difference(m.createdAt!) < editWindow;

  void _onEditStart(
    OnMessageEditStartEvent event,
    Emitter<ConversationViewModelState> emit,
  ) {
    final data = state.data;
    if (data == null || !canEdit(event.message)) return;
    _emitData(emit, data.copyWith(editing: event.message));
  }

  void _onEditCancel(
    OnMessageEditCancelEvent event,
    Emitter<ConversationViewModelState> emit,
  ) {
    final data = state.data;
    if (data == null || data.editing == null) return;
    _emitData(emit, data.copyWith(clearEditing: true));
  }

  Future<void> _onEditSubmit(
    OnMessageEditSubmitEvent event,
    Emitter<ConversationViewModelState> emit,
  ) async {
    final data = state.data;
    final editing = data?.editing;
    final body = event.body.trim();
    if (data == null || editing == null) return;
    // Nothing changed / emptied → just leave edit mode.
    if (body.isEmpty || body == (editing.body ?? '').trim()) {
      _emitData(emit, data.copyWith(clearEditing: true));
      return;
    }
    _emitData(emit, data.copyWith(clearEditing: true)); // banner closes now
    final result = await _repository.editMessage(editing.id, body);
    final now = state.data;
    if (now == null) return;
    result.fold(
      (error) =>
          emit(ConversationActionFailedState(error: error, lastData: now)),
      (edited) => _emitData(emit, _replaceMessage(now, edited)),
    );
  }

  Future<void> _onDelete(
    OnMessageDeleteEvent event,
    Emitter<ConversationViewModelState> emit,
  ) async {
    final result = await _repository.deleteMessage(event.messageId);
    final data = state.data;
    if (data == null) return;
    result.fold(
      (error) =>
          emit(ConversationActionFailedState(error: error, lastData: data)),
      (_) => _emitData(emit, _without(data, event.messageId)),
    );
  }

  /// Optimistic: my reaction flips at once; the server's list then wins;
  /// a failure puts the old list back.
  Future<void> _onReactionToggle(
    OnReactionToggleEvent event,
    Emitter<ConversationViewModelState> emit,
  ) async {
    final data = state.data;
    final me = myId;
    final message = data?.messages.firstWhereOrNull(
      (m) => m.id == event.messageId,
    );
    if (data == null || me == null || message == null || message.deleted) {
      return;
    }
    final before = message.reactions;
    final mine = ReactionModel(userId: me, emoji: event.emoji);
    final flipped = before.contains(mine)
        ? [
            for (final r in before)
              if (r != mine) r,
          ]
        : [...before, mine];
    _emitData(emit, _withReactions(data, message.id, flipped));

    final result = await _repository.toggleReaction(message.id, event.emoji);
    final now = state.data;
    if (now == null) return;
    result.fold(
      (error) => emit(
        ConversationActionFailedState(
          error: error,
          lastData: _withReactions(now, message.id, before),
        ),
      ),
      (server) => _emitData(emit, _withReactions(now, message.id, server)),
    );
  }

  /// Swap in a changed message; keep the read receipts / reactions we
  /// know when the server's copy has none (edit events carry no receipts).
  static ConversationLoadedState _replaceMessage(
    ConversationLoadedState data,
    MessageModel changed,
  ) => data.copyWith(
    messages: [
      for (final m in data.messages)
        m.id == changed.id
            ? changed.copyWith(
                readByUserIds: {...m.readByUserIds, ...changed.readByUserIds},
                reactions: changed.reactions.isEmpty
                    ? m.reactions
                    : changed.reactions,
              )
            : m,
    ],
  );

  static ConversationLoadedState _without(
    ConversationLoadedState data,
    String messageId,
  ) => data.copyWith(
    messages: [
      for (final m in data.messages)
        if (m.id != messageId) m,
    ],
    // deleting the message I was editing → leave edit mode
    clearEditing: data.editing?.id == messageId,
  );

  static ConversationLoadedState _withReactions(
    ConversationLoadedState data,
    String messageId,
    List<ReactionModel> reactions,
  ) => data.copyWith(
    messages: [
      for (final m in data.messages)
        m.id == messageId ? m.copyWith(reactions: reactions) : m,
    ],
  );
}
