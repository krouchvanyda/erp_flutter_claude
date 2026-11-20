import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../model/chat_update.dart';
import '../../repository/chat_repository.dart';

part 'typing_view_model_event.dart';
part 'typing_view_model_state.dart';

/// "Dara is typing…" for ONE conversation (Step 5.6). Two directions:
///
/// ```
/// OUT (me)   text changes ──► "typing: true" at most every [resendEvery]
///            no change for [idleAfter] / text cleared / sent ──► "typing: false"
///
/// IN (them)  typing:true  ──► add them, (re)start a [expireAfter] timer
///            typing:false / their message arrives / timer ends ──► remove them
/// ```
///
/// Why timers on BOTH sides: a "typing: false" can be lost (offline, app
/// killed). Re-sending while typing + expiring on the other side means a
/// stuck "typing…" fixes itself in a few seconds.
class TypingViewModelBloc
    extends Bloc<TypingViewModelEvent, TypingViewModelState> {
  TypingViewModelBloc(
    this._repository, {
    required this.conversationId,
    required this.myId,
    this.resendEvery = const Duration(seconds: 3),
    this.idleAfter = const Duration(seconds: 4),
    this.expireAfter = const Duration(seconds: 6),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now,
       super(const TypingViewModelState()) {
    on<OnTypingTextChangedEvent>(_onTextChanged);
    on<OnTypingStopEvent>((_, _) => _stopMine());
    on<OnTypingIdleEvent>((_, _) => _stopMine());
    on<OnTypingLiveUpdateEvent>(_onLiveUpdate);
    on<OnTypingExpiredEvent>((event, emit) => _remove(emit, event.userId));

    _subscription = _repository
        .conversationUpdates(conversationId)
        .listen((u) => add(OnTypingLiveUpdateEvent(u)));
  }

  final ChatRepository _repository;
  final String conversationId;
  final String? myId;
  final Duration resendEvery;
  final Duration idleAfter;
  final Duration expireAfter;
  final DateTime Function() _now;

  late final StreamSubscription<ChatUpdate> _subscription;

  // ── me ──
  DateTime? _lastSentAt; // last "typing: true"
  bool _iAmTyping = false;
  Timer? _idle;

  // ── them ── userId → its expiry timer
  final Map<String, Timer> _expiry = {};

  @override
  Future<void> close() async {
    _stopMine(); // leaving the chat → tell them I stopped
    _idle?.cancel();
    for (final t in _expiry.values) {
      t.cancel();
    }
    await _subscription.cancel();
    return super.close();
  }

  void _onTextChanged(
    OnTypingTextChangedEvent event,
    Emitter<TypingViewModelState> emit,
  ) {
    if (event.text.trim().isEmpty) {
      _stopMine(); // cleared the box
      return;
    }
    final now = _now();
    final last = _lastSentAt;
    if (!_iAmTyping || last == null || now.difference(last) >= resendEvery) {
      _repository.sendTyping(conversationId, typing: true);
      _lastSentAt = now;
      _iAmTyping = true;
    }
    _idle?.cancel();
    _idle = Timer(idleAfter, () {
      if (!isClosed) add(OnTypingIdleEvent());
    });
  }

  void _stopMine() {
    _idle?.cancel();
    if (!_iAmTyping) return;
    _iAmTyping = false;
    _lastSentAt = null;
    _repository.sendTyping(conversationId, typing: false);
  }

  void _onLiveUpdate(
    OnTypingLiveUpdateEvent event,
    Emitter<TypingViewModelState> emit,
  ) {
    switch (event.update) {
      case TypingChanged(:final conversationId, :final userId, :final typing)
          when conversationId == this.conversationId && userId != myId:
        if (!typing) {
          _remove(emit, userId);
          return;
        }
        _expiry[userId]?.cancel();
        _expiry[userId] = Timer(expireAfter, () {
          if (!isClosed) add(OnTypingExpiredEvent(userId));
        });
        if (!state.userIds.contains(userId)) {
          emit(TypingViewModelState({...state.userIds, userId}));
        }
      case MessageArrived(:final message):
        // their message arrived → they're done typing
        _remove(emit, message.senderId);
      default:
        break;
    }
  }

  void _remove(Emitter<TypingViewModelState> emit, String userId) {
    _expiry.remove(userId)?.cancel();
    if (!state.userIds.contains(userId)) return;
    emit(
      TypingViewModelState({
        for (final id in state.userIds)
          if (id != userId) id,
      }),
    );
  }
}
