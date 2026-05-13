import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_result.freezed.dart';

/// One row returned by a [SearchProvider]'s response (Slice 2.1.3).
///
/// **Wire-friendly**: only primitives + maps, no Flutter imports. Icons
/// and result-rendering live in the widget layer (the UI looks `iconOf`
/// up by [providerId]).
///
/// **Navigation**: tapping a result calls
/// `context.goNamed(routeName, pathParameters: pathParameters)`. The
/// route guard (Slice 1.3.2) provides defense-in-depth — if a result
/// for an unauthorised route somehow leaks past the provider's own
/// permission filter, the redirect bounces to `/forbidden`.
@freezed
class SearchResult with _$SearchResult {
  const factory SearchResult({
    /// Stable identity within [providerId] — used for keying widgets and
    /// deduping within a provider's own response.
    required String id,

    /// Primary line shown in the result tile.
    required String title,

    /// Optional secondary line (record code, customer name, etc.).
    String? subtitle,

    /// Which provider produced this row — drives grouping in the UI.
    required String providerId,

    /// `go_router` named route to push when the user taps the result.
    required String routeName,

    /// Path parameters passed alongside [routeName].
    @Default(<String, String>{}) Map<String, String> pathParameters,
  }) = _SearchResult;
}

/// Aggregated response from one provider: the provider id + its rows.
/// `FederatedSearchUseCase` returns a list of these so the UI can
/// render section headers per module.
@freezed
class SearchResultGroup with _$SearchResultGroup {
  const factory SearchResultGroup({
    required String providerId,
    required List<SearchResult> results,
  }) = _SearchResultGroup;
}
