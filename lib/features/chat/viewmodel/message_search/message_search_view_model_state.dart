part of 'message_search_view_model_bloc.dart';

@immutable
sealed class MessageSearchViewModelState {
  const MessageSearchViewModelState(this.query);

  /// The text the results belong to.
  final String query;
}

/// Empty box → "Search in this chat".
final class MessageSearchInitial extends MessageSearchViewModelState {
  const MessageSearchInitial() : super('');
}

final class MessageSearchLoadingState extends MessageSearchViewModelState {
  const MessageSearchLoadingState(super.query);
}

final class MessageSearchLoadedState extends MessageSearchViewModelState {
  const MessageSearchLoadedState(
    super.query, {
    required this.results,
    required this.page,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  /// Newest first (the server's order).
  final List<MessageModel> results;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  MessageSearchLoadedState copyWith({
    List<MessageModel>? results,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) => MessageSearchLoadedState(
    query,
    results: results ?? this.results,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  static const _eq = ListEquality<MessageModel>();

  @override
  bool operator ==(Object other) =>
      other is MessageSearchLoadedState &&
      other.query == query &&
      _eq.equals(other.results, results) &&
      other.page == page &&
      other.hasMore == hasMore &&
      other.isLoadingMore == isLoadingMore;

  @override
  int get hashCode =>
      Object.hash(query, _eq.hash(results), page, hasMore, isLoadingMore);
}

final class MessageSearchErrorState extends MessageSearchViewModelState {
  const MessageSearchErrorState(super.query, this.error);

  final NetworkErrorModel error;
}
