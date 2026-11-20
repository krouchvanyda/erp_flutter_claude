part of 'typing_view_model_bloc.dart';

@immutable
sealed class TypingViewModelEvent {}

/// The composer's text changed (from the page).
final class OnTypingTextChangedEvent extends TypingViewModelEvent {
  OnTypingTextChangedEvent(this.text);

  final String text;
}

/// I sent the message / left the chat → "stopped typing" now.
final class OnTypingStopEvent extends TypingViewModelEvent {}

/// A live update (added by the bloc itself from the conversation topic).
final class OnTypingLiveUpdateEvent extends TypingViewModelEvent {
  OnTypingLiveUpdateEvent(this.update);

  final ChatUpdate update;
}

/// Nobody refreshed [userId]'s "typing" in time → drop them (internal).
final class OnTypingExpiredEvent extends TypingViewModelEvent {
  OnTypingExpiredEvent(this.userId);

  final String userId;
}

/// I stopped typing for a while (internal idle timer).
final class OnTypingIdleEvent extends TypingViewModelEvent {}
