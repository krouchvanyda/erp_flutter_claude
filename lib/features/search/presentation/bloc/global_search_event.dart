import 'package:equatable/equatable.dart';

/// Inputs to [GlobalSearchBloc] — kept tiny: the search bar emits one
/// event on every keystroke; the bloc handles debouncing internally
/// via an event transformer.
sealed class GlobalSearchEvent extends Equatable {
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
  List<Object?> get props => [query];
}

class GlobalSearchCleared extends GlobalSearchEvent {
  const GlobalSearchCleared();
  @override
  List<Object?> get props => const [];
}
