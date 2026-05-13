import '../entities/inventory_item.dart';

/// Pure filter + sort over an inventory catalog (Slice 5.1.1). Mirrors
/// the shape of `applyInvoiceQuery` so the bloc stays thin and the
/// business rules are exhaustively testable.
List<InventoryItem> applyItemQuery(
  List<InventoryItem> all, {
  Set<String> warehouseFilter = const {},
  bool onlyLowStock = false,
  String searchQuery = '',
  InventoryItemSort sort = InventoryItemSort.nameAsc,
}) {
  Iterable<InventoryItem> result = all;

  if (warehouseFilter.isNotEmpty) {
    result = result.where((i) => warehouseFilter.contains(i.warehouseCode));
  }
  if (onlyLowStock) {
    result = result.where((i) => i.isLowStock);
  }

  final q = searchQuery.trim().toLowerCase();
  if (q.isNotEmpty) {
    result = result.where((i) =>
        i.sku.toLowerCase().contains(q) ||
        i.name.toLowerCase().contains(q) ||
        i.locationCode.toLowerCase().contains(q) ||
        (i.barcode?.toLowerCase().contains(q) ?? false));
  }

  final list = result.toList();
  switch (sort) {
    case InventoryItemSort.nameAsc:
      list.sort((a, b) => a.name.compareTo(b.name));
    case InventoryItemSort.skuAsc:
      list.sort((a, b) => a.sku.compareTo(b.sku));
    case InventoryItemSort.onHandAsc:
      list.sort((a, b) => a.onHandQty.compareTo(b.onHandQty));
    case InventoryItemSort.onHandDesc:
      list.sort((a, b) => b.onHandQty.compareTo(a.onHandQty));
  }
  return list;
}
