import 'package:collection/collection.dart';

import '../../domain/entities/search_result.dart';

/// State machine for the global search bar.
///
/// Plain Dart 3 `sealed class` (was `freezed`). Factory redirects preserve
/// `GlobalSearchState.success(...)` etc.; the view switches on the
/// subtypes. Value `==`/`hashCode` kept for `BlocBuilder` dedupe.
sealed class GlobalSearchState {
  const GlobalSearchState();

  const factory GlobalSearchState.idle() = GlobalSearchIdle;
  const factory GlobalSearchState.loading(String query) = GlobalSearchLoading;
  const factory GlobalSearchState.success({
    required String query,
    required List<SearchResultGroup> groups,
  }) = GlobalSearchSuccess;
  const factory GlobalSearchState.failure({
    required String query,
    required String message,
  }) = GlobalSearchFailure;
}

class GlobalSearchIdle extends GlobalSearchState {
  const GlobalSearchIdle();

  @override
  bool operator ==(Object other) => other is GlobalSearchIdle;
  @override
  int get hashCode => (GlobalSearchIdle).hashCode;
}

class GlobalSearchLoading extends GlobalSearchState {
  const GlobalSearchLoading(this.query);
  final String query;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalSearchLoading && other.query == query);
  @override
  int get hashCode => query.hashCode;
}

class GlobalSearchSuccess extends GlobalSearchState {
  const GlobalSearchSuccess({required this.query, required this.groups});
  final String query;
  final List<SearchResultGroup> groups;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalSearchSuccess &&
          other.query == query &&
          const ListEquality<SearchResultGroup>()
              .equals(other.groups, groups));
  @override
  int get hashCode => Object.hash(
        query,
        const ListEquality<SearchResultGroup>().hash(groups),
      );
}

class GlobalSearchFailure extends GlobalSearchState {
  const GlobalSearchFailure({required this.query, required this.message});
  final String query;
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalSearchFailure &&
          other.query == query &&
          other.message == message);
  @override
  int get hashCode => Object.hash(query, message);
}
