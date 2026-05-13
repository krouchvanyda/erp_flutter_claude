import '../entities/inventory_item.dart';

/// Result of a low-stock sweep (Slice 5.1.3).
class LowStockReport {
  const LowStockReport({
    required this.allLowStock,
    required this.newlyAlerted,
  });

  /// Every active item currently at or below its reorder point.
  final List<InventoryItem> allLowStock;

  /// Subset of [allLowStock] that wasn't on the previous alert pass —
  /// the caller fires *one* notification per new event so we don't
  /// spam the user with the same item every minute.
  final List<InventoryItem> newlyAlerted;
}

/// Pure low-stock sweep. The `previouslyAlertedIds` set lets the caller
/// debounce notifications across runs — only items that *just* crossed
/// the reorder threshold land in [LowStockReport.newlyAlerted].
///
/// **Discontinued / blocked** items are skipped — they shouldn't push
/// alerts even when their on-hand is zero.
LowStockReport checkLowStock(
  Iterable<InventoryItem> items, {
  Set<String> previouslyAlertedIds = const {},
}) {
  final all = <InventoryItem>[];
  final fresh = <InventoryItem>[];
  for (final item in items) {
    if (item.status != InventoryItemStatus.active) continue;
    if (!item.isLowStock) continue;
    all.add(item);
    if (!previouslyAlertedIds.contains(item.id)) {
      fresh.add(item);
    }
  }
  return LowStockReport(allLowStock: all, newlyAlerted: fresh);
}
