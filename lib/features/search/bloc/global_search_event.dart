/// Inputs to [GlobalSearchBloc].
///
/// Plain Dart 3 `sealed class` (was `freezed`). Factory redirects preserve
/// `GlobalSearchEvent.queryChanged(...)`; the bloc's `on<...>` handlers
/// match the subtypes.
sealed class GlobalSearchEvent {
  const GlobalSearchEvent();

  /// User typed (or programmatic seed).
  const factory GlobalSearchEvent.queryChanged(String query) =
      GlobalSearchQueryChanged;

  /// Hard reset — bar closed, cleared, etc.
  const factory GlobalSearchEvent.cleared() = GlobalSearchCleared;
}

class GlobalSearchQueryChanged extends GlobalSearchEvent {
  const GlobalSearchQueryChanged(this.query);
  final String query;
}

class GlobalSearchCleared extends GlobalSearchEvent {
  const GlobalSearchCleared();
}
