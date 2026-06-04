import 'package:collection/collection.dart';

/// One row returned by a [SearchProvider]'s response (Slice 2.1.3).
///
/// Pure value type — no Flutter imports — so the entity is unit-testable
/// in pure-Dart tests. Icons and result-rendering live in the widget
/// layer (the UI looks `iconOf` up by [providerId]).
///
/// **Navigation**: the result carries no page reference. Consumers
/// dispatch on `(providerId, id)`: for `providerId == 'modules'`, the
/// UI looks up the matching [ModuleShortcut] in [ModuleShortcutCatalog]
/// by `id` and calls its `builder()` via `ConfigRouter`.
class SearchResult {
  const SearchResult({
    required this.id,
    required this.title,
    this.subtitle,
    required this.providerId,
  });

  /// Stable identity within [providerId] — used for keying widgets,
  /// deduping within a provider's own response, AND for the consumer
  /// to look up the destination page (e.g. by matching against
  /// [ModuleShortcutCatalog]).
  final String id;

  /// Primary line shown in the result tile.
  final String title;

  /// Optional secondary line (record code, customer name, etc.).
  final String? subtitle;

  /// Which provider produced this row — drives grouping in the UI
  /// AND the navigation dispatch.
  final String providerId;

  static const Object _undefined = Object();

  SearchResult copyWith({
    String? id,
    String? title,
    Object? subtitle = _undefined,
    String? providerId,
  }) {
    return SearchResult(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle:
          identical(subtitle, _undefined) ? this.subtitle : subtitle as String?,
      providerId: providerId ?? this.providerId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          subtitle == other.subtitle &&
          providerId == other.providerId;

  @override
  int get hashCode => Object.hash(runtimeType, id, title, subtitle, providerId);
}

/// Aggregated response from one provider: the provider id + its rows.
/// `FederatedSearchUseCase` returns a list of these so the UI can
/// render section headers per module.
class SearchResultGroup {
  const SearchResultGroup({
    required this.providerId,
    required this.results,
  });

  final String providerId;
  final List<SearchResult> results;

  SearchResultGroup copyWith({
    String? providerId,
    List<SearchResult>? results,
  }) {
    return SearchResultGroup(
      providerId: providerId ?? this.providerId,
      results: results ?? this.results,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResultGroup &&
          runtimeType == other.runtimeType &&
          providerId == other.providerId &&
          const ListEquality<SearchResult>().equals(results, other.results);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        providerId,
        const ListEquality<SearchResult>().hash(results),
      );
}
