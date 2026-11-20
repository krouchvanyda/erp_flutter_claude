part of 'inbox_view_model_bloc.dart';

@immutable
sealed class InboxViewModelEvent {}

/// Page opened, pull-to-refresh, or "Try again" → page 1.
///
/// [done] (optional) is completed when the load has FINISHED — success,
/// error, or "nothing changed". Pull-to-refresh awaits it to stop its
/// spinner. Don't wait for a new state instead: Bloc does NOT emit a state
/// that is `==` the current one, so an unchanged list emits nothing.
final class OnInboxLoadEvent extends InboxViewModelEvent {
  OnInboxLoadEvent({this.done});

  final Completer<void>? done;
}

/// Scrolled near the end → the next page (if there is one).
final class OnInboxLoadMoreEvent extends InboxViewModelEvent {}

/// A live change from the server (Step 5.3). Added by the bloc itself from
/// `ChatRepository.inboxUpdates()`, not by the page.
final class OnInboxLiveUpdateEvent extends InboxViewModelEvent {
  OnInboxLiveUpdateEvent(this.update);

  final ChatUpdate update;
}

/// The user opened ([conversationId]) or closed (null) a conversation.
/// While it's open, its new messages don't count as unread.
final class OnInboxConversationOpenedEvent extends InboxViewModelEvent {
  OnInboxConversationOpenedEvent(this.conversationId);

  final String? conversationId;
}
