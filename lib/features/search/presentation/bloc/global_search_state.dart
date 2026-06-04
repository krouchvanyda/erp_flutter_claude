import 'package:equatable/equatable.dart';

import '../../domain/entities/search_result.dart';

/// State machine for the global search bar.
///
/// **State carries the query** so the widget can decorate the bar (loader
/// near the input, "no results for X" copy) without keeping its own
/// shadow copy.
sealed class GlobalSearchState extends Equatable {
  const GlobalSearchState();

  /// No query yet — show empty / suggestion content.
  const factory GlobalSearchState.idle() = GlobalSearchIdle;

  /// Query is in flight. The previous results (if any) are intentionally
  /// dropped so a stale list doesn't sit under a fresh spinner.
  const factory GlobalSearchState.loading(String query) = GlobalSearchLoading;

  /// Query completed — [groups] preserves provider order so the section
  /// list is stable. Empty groups are filtered out by the use case, so
  /// `groups.isEmpty` here means "nothing matched at all".
  const factory GlobalSearchState.success({
    required String query,
    required List<SearchResultGroup> groups,
  }) = GlobalSearchSuccess;

  /// All providers threw, or the use case itself blew up. Per-provider
  /// failures are absorbed; the user only sees this on a total wipeout.
  const factory GlobalSearchState.failure({
    required String query,
    required String message,
  }) = GlobalSearchFailure;
}

class GlobalSearchIdle extends GlobalSearchState {
  const GlobalSearchIdle();
  @override
  List<Object?> get props => const [];
}

class GlobalSearchLoading extends GlobalSearchState {
  const GlobalSearchLoading(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

class GlobalSearchSuccess extends GlobalSearchState {
  const GlobalSearchSuccess({
    required this.query,
    required this.groups,
  });
  final String query;
  final List<SearchResultGroup> groups;
  @override
  List<Object?> get props => [query, groups];
}

class GlobalSearchFailure extends GlobalSearchState {
  const GlobalSearchFailure({
    required this.query,
    required this.message,
  });
  final String query;
  final String message;
  @override
  List<Object?> get props => [query, message];
}
