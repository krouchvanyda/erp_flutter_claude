part of 'inbox_view_model_bloc.dart';

@immutable
sealed class InboxViewModelEvent {}

/// Page opened, pull-to-refresh, or "Try again" → page 1.
final class OnInboxLoadEvent extends InboxViewModelEvent {}

/// Scrolled near the end → the next page (if there is one).
final class OnInboxLoadMoreEvent extends InboxViewModelEvent {}
