part of 'message_search_view_model_bloc.dart';

@immutable
sealed class MessageSearchViewModelEvent {}

/// The search box changed (every key). The bloc waits a moment
/// ([MessageSearchViewModelBloc.debounce]) before asking the server.
final class OnSearchQueryChangedEvent extends MessageSearchViewModelEvent {
  OnSearchQueryChangedEvent(this.query);

  final String query;
}

/// The typing paused → search now (internal, from the debounce timer).
final class OnSearchRunEvent extends MessageSearchViewModelEvent {
  OnSearchRunEvent(this.query);

  final String query;
}

/// Scrolled near the end → the next page of results.
final class OnSearchLoadMoreEvent extends MessageSearchViewModelEvent {}
