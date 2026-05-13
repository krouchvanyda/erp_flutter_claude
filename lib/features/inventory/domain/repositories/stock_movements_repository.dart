import '../entities/stock_movement.dart';

/// Domain contract for the inventory ledger (Slice 5.1.2).
abstract class StockMovementsRepository {
  Future<List<StockMovement>> forItem(String itemId);
  Stream<List<StockMovement>> watchForItem(String itemId);

  /// Appends a new movement (Slices 5.2.2 / 5.2.3 / 5.2.4). Returns
  /// the persisted record (the repo assigns the id + timestamp).
  Future<StockMovement> append(StockMovement draft);
}
