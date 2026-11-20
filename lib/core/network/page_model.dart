import 'package:collection/collection.dart';

/// One page of a list endpoint (the backend's `PageResponse`):
///
/// ```json
/// { "items": [ ... ], "page": 1, "pageSize": 20, "totalItems": 134, "totalPages": 7 }
/// ```
///
/// Generic: `PageModel<ConversationModel>`, `PageModel<MessageModel>`, …
/// Pages are 1-based (page 1 = first page), like the backend.
class PageModel<T> {
  const PageModel({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  /// Is there a next page to load?
  bool get hasMore => page < totalPages;

  /// [itemFromJson] turns ONE item into a model, e.g.
  /// `ConversationModel.fromJson`. A missing / null list becomes empty.
  static PageModel<T> fromData<T>(
    Object? data,
    T Function(Map<String, dynamic> json) itemFromJson,
  ) {
    final json = data as Map<String, dynamic>;
    return PageModel<T>(
      items: [
        for (final item in json['items'] as List? ?? const [])
          itemFromJson(item as Map<String, dynamic>),
      ],
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PageModel<T> &&
      const ListEquality<Object?>().equals(other.items, items) &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.totalItems == totalItems &&
      other.totalPages == totalPages;

  @override
  int get hashCode => Object.hash(
    const ListEquality<Object?>().hash(items),
    page,
    pageSize,
    totalItems,
    totalPages,
  );

  @override
  String toString() =>
      'PageModel(page $page/$totalPages, ${items.length} items)';
}
