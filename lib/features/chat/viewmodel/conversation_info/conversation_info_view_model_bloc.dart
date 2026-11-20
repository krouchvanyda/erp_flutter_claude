import 'dart:async';

import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_error_model.dart';
import '../../model/chat_enums.dart';
import '../../model/chat_update.dart';
import '../../model/conversation_model.dart';
import '../../repository/chat_repository.dart';
import '../../repository/presence_store.dart';

part 'conversation_info_view_model_event.dart';
part 'conversation_info_view_model_state.dart';

/// The CURRENT conversation (name, members) + the group actions (Step 5.4).
///
/// Created by `ConversationPage`, so the chat's title AND the info page
/// share it: rename on the info page → the title changes too.
///
/// ```
/// rename / add / remove  ──► Ready(updated conversation)  or Failed
/// leave / delete         ──► Gone(left / deleted)        or Failed
/// live conversation.update ──► Ready(updated)
/// live conversation.remove ──► Gone(removed)
/// ```
class ConversationInfoViewModelBloc
    extends
        Bloc<ConversationInfoViewModelEvent, ConversationInfoViewModelState> {
  ConversationInfoViewModelBloc(
    this._repository, {
    required ConversationModel conversation,
    required this.myId,
    PresenceStore? presence,
  }) : super(ConversationInfoReadyState(conversation)) {
    // Direct chat → follow the other person's online status (5.6).
    final other = conversation.isGroup ? null : conversation.otherMember(myId);
    if (presence != null && other != null) {
      unawaited(presence.watch([other.userId]));
    }
    on<OnInfoRenameEvent>(_onRename);
    on<OnInfoRemoveMemberEvent>(_onRemoveMember);
    on<OnInfoLeaveEvent>(_onLeave);
    on<OnInfoDeleteEvent>(_onDelete);
    on<OnInfoConversationChangedEvent>(
      (event, emit) => _ready(emit, event.conversation),
    );
    on<OnInfoLiveUpdateEvent>(_onLiveUpdate);

    final id = conversation.id;
    _subscriptions = [
      // name / members change → the conversation topic
      _repository
          .conversationUpdates(id)
          .listen((u) => add(OnInfoLiveUpdateEvent(u))),
      // "you were removed / it was deleted" → only MY inbox queue
      _repository.inboxUpdates().listen((u) => add(OnInfoLiveUpdateEvent(u))),
    ];
  }

  final ChatRepository _repository;
  final String? myId;
  late final List<StreamSubscription<Object?>> _subscriptions;

  String get _id => state.conversation.id;

  /// Admin of THIS group? (Hides admin-only buttons; the server checks too.)
  bool get isAdmin => state.conversation.members.any(
    (m) => m.userId == myId && m.role == MemberRole.admin,
  );

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    return super.close();
  }

  Future<void> _onRename(
    OnInfoRenameEvent event,
    Emitter<ConversationInfoViewModelState> emit,
  ) async {
    final name = event.name.trim();
    if (name.isEmpty || name == state.conversation.name) return;
    await _run(emit, () => _repository.rename(_id, name));
  }

  Future<void> _onRemoveMember(
    OnInfoRemoveMemberEvent event,
    Emitter<ConversationInfoViewModelState> emit,
  ) => _run(emit, () => _repository.removeMember(_id, event.userId));

  Future<void> _onLeave(
    OnInfoLeaveEvent event,
    Emitter<ConversationInfoViewModelState> emit,
  ) =>
      _runGone(emit, () => _repository.leave(_id), ConversationGoneReason.left);

  Future<void> _onDelete(
    OnInfoDeleteEvent event,
    Emitter<ConversationInfoViewModelState> emit,
  ) => _runGone(
    emit,
    () => _repository.deleteConversation(_id),
    ConversationGoneReason.deleted,
  );

  void _onLiveUpdate(
    OnInfoLiveUpdateEvent event,
    Emitter<ConversationInfoViewModelState> emit,
  ) {
    if (state is ConversationInfoGoneState) return;
    switch (event.update) {
      case ConversationChanged(:final conversation) when conversation.id == _id:
        // removed by an admin → the update no longer lists me
        if (myId != null &&
            !conversation.members.any((m) => m.userId == myId)) {
          emit(
            ConversationInfoGoneState(
              conversation,
              ConversationGoneReason.removed,
            ),
          );
        } else {
          _ready(emit, conversation);
        }
      case ConversationRemoved(:final conversationId)
          when conversationId == _id:
        emit(
          ConversationInfoGoneState(
            state.conversation,
            ConversationGoneReason.removed,
          ),
        );
      default:
        break; // other chats, messages
    }
  }

  /// An action that returns the updated conversation.
  Future<void> _run(
    Emitter<ConversationInfoViewModelState> emit,
    Future<Either<NetworkErrorModel, ConversationModel>> Function() call,
  ) async {
    if (_busy) return;
    emit(ConversationInfoReadyState(state.conversation, isBusy: true));
    final result = await call();
    if (state is ConversationInfoGoneState) return; // a live remove won
    result.fold(
      (error) => emit(ConversationInfoFailedState(state.conversation, error)),
      (updated) => _ready(emit, updated),
    );
  }

  /// An action after which the chat is gone for me (leave / delete).
  Future<void> _runGone(
    Emitter<ConversationInfoViewModelState> emit,
    Future<Either<NetworkErrorModel, void>> Function() call,
    ConversationGoneReason reason,
  ) async {
    if (_busy) return;
    emit(ConversationInfoReadyState(state.conversation, isBusy: true));
    final result = await call();
    if (state is ConversationInfoGoneState) return;
    result.fold(
      (error) => emit(ConversationInfoFailedState(state.conversation, error)),
      (_) => emit(ConversationInfoGoneState(state.conversation, reason)),
    );
  }

  bool get _busy {
    final s = state;
    return s is ConversationInfoGoneState ||
        (s is ConversationInfoReadyState && s.isBusy);
  }

  void _ready(
    Emitter<ConversationInfoViewModelState> emit,
    ConversationModel conversation,
  ) {
    // The server's DTO may carry the actor's unreadCount (5.3 quirk); the
    // info page doesn't show it, so it doesn't matter here.
    emit(ConversationInfoReadyState(conversation));
  }
}
