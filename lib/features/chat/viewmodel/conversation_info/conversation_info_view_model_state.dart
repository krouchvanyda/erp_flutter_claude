part of 'conversation_info_view_model_bloc.dart';

/// Why the conversation is no longer mine → the page closes and says so.
enum ConversationGoneReason {
  left, //     I pressed "Leave group"
  deleted, //  I deleted it
  removed, //  someone else removed me, or deleted it
}

@immutable
sealed class ConversationInfoViewModelState {
  const ConversationInfoViewModelState(this.conversation);

  /// ALWAYS there: the info page and the chat's title draw it.
  final ConversationModel conversation;
}

/// Normal. [isBusy] → an action is on its way (spinner, actions disabled).
final class ConversationInfoReadyState extends ConversationInfoViewModelState {
  const ConversationInfoReadyState(super.conversation, {this.isBusy = false});

  final bool isBusy;

  @override
  bool operator ==(Object other) =>
      other is ConversationInfoReadyState &&
      other.conversation == conversation &&
      other.isBusy == isBusy;

  @override
  int get hashCode => Object.hash(conversation, isBusy);
}

/// An action failed (403 "Admin role required", offline…) → snackbar.
final class ConversationInfoFailedState extends ConversationInfoViewModelState {
  const ConversationInfoFailedState(super.conversation, this.error);

  final NetworkErrorModel error;
}

/// The chat is gone for me → close the chat + info pages.
final class ConversationInfoGoneState extends ConversationInfoViewModelState {
  const ConversationInfoGoneState(super.conversation, this.reason);

  final ConversationGoneReason reason;
}
