/// Pure-Dart pagination slicer (Slice 3.3.2).
///
/// Returns the page-sized slice of [items] for the given 0-indexed
/// [pageIndex]. Out-of-range pages return empty (not an error) so the
/// UI can degrade gracefully when the user lingers on the last page
/// while the underlying list shrinks.
///
/// **Why not `items.skip(...).take(...)`**: the eager `toList` fixes
/// the result to a non-growable view, which is what the renderer wants.
List<T> paginate<T>(List<T> items, {required int pageIndex, required int pageSize}) {
  if (pageSize <= 0) {
    throw ArgumentError.value(pageSize, 'pageSize', 'must be > 0');
  }
  if (pageIndex < 0) {
    throw ArgumentError.value(pageIndex, 'pageIndex', 'must be >= 0');
  }
  final start = pageIndex * pageSize;
  if (start >= items.length) return const [];
  final end = (start + pageSize).clamp(0, items.length);
  return items.sublist(start, end);
}

/// Total number of pages required to fit [totalItems] at [pageSize].
/// Always at least 1 (so a "page 1 of 1" header still renders for
/// empty lists).
int pageCount({required int totalItems, required int pageSize}) {
  if (pageSize <= 0) {
    throw ArgumentError.value(pageSize, 'pageSize', 'must be > 0');
  }
  if (totalItems <= 0) return 1;
  return (totalItems + pageSize - 1) ~/ pageSize;
}
