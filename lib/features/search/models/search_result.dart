import 'package:collection/collection.dart';

/// One row returned by a `SearchProvider`'s response (Slice 2.1.3).
///
/// Pure value type — no Flutter imports. Plain immutable class (was
/// `freezed`; the codegen was removed).
class SearchResult {
  const SearchResult({
    required this.id,
    required this.title,
    this.subtitle,
    required this.providerId,
  });

  /// Stable identity within [providerId].
  final String id;

  /// Primary line shown in the result tile.
  final String title;

  /// Optional secondary line.
  final String? subtitle;

  /// Which provider produced this row.
  final String providerId;

  SearchResult copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? providerId,
  }) =>
      SearchResult(
        id: id ?? this.id,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        providerId: providerId ?? this.providerId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchResult &&
          other.id == id &&
          other.title == title &&
          other.subtitle == subtitle &&
          other.providerId == providerId);

  @override
  int get hashCode => Object.hash(id, title, subtitle, providerId);
}

/// Aggregated response from one provider: the provider id + its rows.
class SearchResultGroup {
  const SearchResultGroup({
    required this.providerId,
    required this.results,
  });

  final String providerId;
  final List<SearchResult> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchResultGroup &&
          other.providerId == providerId &&
          const ListEquality<SearchResult>().equals(other.results, results));

  @override
  int get hashCode => Object.hash(
        providerId,
        const ListEquality<SearchResult>().hash(results),
      );
}
