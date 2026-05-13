import '../entities/goods_receipt.dart';
import '../entities/purchase_order.dart';

abstract class PurchaseOrdersRepository {
  Future<List<PurchaseOrder>> getAll();
  Stream<List<PurchaseOrder>> watchAll();
  Future<PurchaseOrder?> findById(String id);

  /// Persists a freshly created PO (Slice 4.2.2 PR→PO conversion).
  /// Returns the persisted record (id assigned by the repo).
  Future<PurchaseOrder> create(PurchaseOrder draft);

  /// Records a goods receipt (Slice 4.2.3). The repo updates each
  /// line's `receivedQuantity` and recomputes the PO's status.
  /// Throws [StateError] if the PO is unknown or any receipt line
  /// over-receives (caller should pre-validate via
  /// [`validateGoodsReceipt`] for a UI-friendly error).
  Future<void> recordGoodsReceipt(GoodsReceipt receipt);

  /// Receipt history for a PO. Empty list if none yet recorded.
  Future<List<GoodsReceipt>> receiptsFor(String purchaseOrderId);
}
