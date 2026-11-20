part of 'inbox_view_model_bloc.dart';

@immutable
sealed class InboxViewModelState {
  /// The list to draw, if any. The page asks this instead of checking every
  /// state type (same idea as the profile page).
  InboxLoadedState? get data => null;
}

final class InboxViewModelInitial extends InboxViewModelState {}

/// First load → full-page spinner.
final class InboxLoadingState extends InboxViewModelState {}

final class InboxLoadedState extends InboxViewModelState {
  InboxLoadedState({
    required this.conversations,
    required this.myId,
    required this.page,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<ConversationModel> conversations;

  /// MY user id (from the token) — the tile needs it for titles + "You: ".
  final String? myId;

  /// The last page loaded (1-based).
  final int page;
  final bool hasMore;

  /// Next page on its way → small spinner at the bottom of the list.
  final bool isLoadingMore;

  @override
  InboxLoadedState get data => this;

  InboxLoadedState copyWith({
    List<ConversationModel>? conversations,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) => InboxLoadedState(
    conversations: conversations ?? this.conversations,
    myId: myId,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  static const _listEq = ListEquality<ConversationModel>();

  // == lets `buildWhen` skip a rebuild when a refresh brings the same list.
  @override
  bool operator ==(Object other) =>
      other is InboxLoadedState &&
      _listEq.equals(other.conversations, conversations) &&
      other.myId == myId &&
      other.page == page &&
      other.hasMore == hasMore &&
      other.isLoadingMore == isLoadingMore;

  @override
  int get hashCode => Object.hash(
    _listEq.hash(conversations),
    myId,
    page,
    hasMore,
    isLoadingMore,
  );
}

/// Load failed.
/// - [lastData] null → nothing to show → error view + "Try again".
/// - [lastData] set  → refresh / load-more failed → keep the list + snackbar.
final class InboxErrorState extends InboxViewModelState {
  InboxErrorState({required this.error, this.lastData});

  final NetworkErrorModel error;
  final InboxLoadedState? lastData;

  @override
  InboxLoadedState? get data => lastData?.copyWith(isLoadingMore: false);
}
