import '../entities/inventory_item.dart';

/// Domain contract for inventory items (Phase 5.1).
abstract class ItemsRepository {
  Future<List<InventoryItem>> getAll();
  Stream<List<InventoryItem>> watchAll();
  Future<InventoryItem?> findById(String id);

  /// Lookup by exact barcode payload (Slice 5.2.1 scanner flow).
  Future<InventoryItem?> findByBarcode(String barcode);

  /// Distinct warehouse codes — drives the toolbar filter chips.
  Future<List<String>> warehouseCodes();

  /// Persists a new on-hand value for [itemId] (Slice 5.2.x mutations
  /// flow through here). Throws [StateError] when the id is unknown.
  Future<InventoryItem> setOnHand(String itemId, num newQty);
}
