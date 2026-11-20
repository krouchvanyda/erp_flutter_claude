part of 'conversation_view_model_bloc.dart';

@immutable
sealed class ConversationViewModelEvent {}

/// Page opened, or "Try again" → page 1 (the latest messages).
///
/// [done] is completed when the load has finished (same idea as the inbox:
/// an unchanged list emits no new state).
final class OnConversationLoadEvent extends ConversationViewModelEvent {
  OnConversationLoadEvent({this.done});

  final Completer<void>? done;
}

/// Scrolled near the TOP (the oldest message) → the next older page.
final class OnConversationLoadOlderEvent extends ConversationViewModelEvent {}

/// ➤ tapped. Blank text is ignored.
final class OnMessageSendEvent extends ConversationViewModelEvent {
  OnMessageSendEvent(this.text);

  final String text;
}

/// "Not sent · Retry" tapped on a failed bubble.
final class OnMessageRetryEvent extends ConversationViewModelEvent {
  OnMessageRetryEvent(this.localId);

  final String localId;
}

/// A live change from the server (Step 5.3), from
/// `ChatRepository.conversationUpdates(id)`. Added by the bloc itself.
final class OnConversationLiveUpdateEvent extends ConversationViewModelEvent {
  OnConversationLiveUpdateEvent(this.update);

  final ChatUpdate update;
}
