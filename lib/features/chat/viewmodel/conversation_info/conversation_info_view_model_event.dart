part of 'conversation_info_view_model_bloc.dart';

@immutable
sealed class ConversationInfoViewModelEvent {}

/// ✎ → new group name (admin).
final class OnInfoRenameEvent extends ConversationInfoViewModelEvent {
  OnInfoRenameEvent(this.name);

  final String name;
}

/// "Remove" on a member (admin, after "Are you sure?").
final class OnInfoRemoveMemberEvent extends ConversationInfoViewModelEvent {
  OnInfoRemoveMemberEvent(this.userId);

  final String userId;
}

/// "Leave group" (after "Are you sure?").
final class OnInfoLeaveEvent extends ConversationInfoViewModelEvent {}

/// "Delete group / chat" (after "Are you sure?").
final class OnInfoDeleteEvent extends ConversationInfoViewModelEvent {}

/// The add-members picker came back with the updated group.
final class OnInfoConversationChangedEvent
    extends ConversationInfoViewModelEvent {
  OnInfoConversationChangedEvent(this.conversation);

  final ConversationModel conversation;
}

/// A live change (Step 5.3 stream), added by the bloc itself.
final class OnInfoLiveUpdateEvent extends ConversationInfoViewModelEvent {
  OnInfoLiveUpdateEvent(this.update);

  final ChatUpdate update;
}
