/// Inputs to [GlobalSearchBloc] — kept tiny: the search bar emits one
/// event on every keystroke; the bloc handles debouncing internally
/// via an event transformer.
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
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalSearchQueryChanged &&
          runtimeType == other.runtimeType &&
          query == other.query;

  @override
  int get hashCode => Object.hash(runtimeType, query);
}

class GlobalSearchCleared extends GlobalSearchEvent {
  const GlobalSearchCleared();
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalSearchCleared && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
