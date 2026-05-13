import '../entities/goods_receipt.dart';
import '../entities/purchase_order.dart';

/// Result codes for goods-receipt validation (Slice 4.2.3). The form
/// surfaces these as inline field errors before a submit hits the repo.
enum GoodsReceiptError {
  poClosed,
  noLines,
  nonPositiveQuantity,
  unknownLineId,
  exceedsOutstanding,
}

/// Pure validator for a goods receipt against a PO snapshot.
///
/// Returns `null` on valid, an error code otherwise. The repo also
/// throws on persist (defence-in-depth) but the form path uses this
/// for fast user feedback.
GoodsReceiptError? validateGoodsReceipt(
  GoodsReceipt receipt,
  PurchaseOrder po,
) {
  if (po.status == PurchaseOrderStatus.closed ||
      po.status == PurchaseOrderStatus.cancelled ||
      po.status == PurchaseOrderStatus.fullyReceived) {
    return GoodsReceiptError.poClosed;
  }
  if (receipt.lines.isEmpty) return GoodsReceiptError.noLines;

  final byId = {for (final l in po.lineItems) l.id: l};
  for (final l in receipt.lines) {
    if (l.quantity <= 0) return GoodsReceiptError.nonPositiveQuantity;
    final poLine = byId[l.purchaseOrderLineId];
    if (poLine == null) return GoodsReceiptError.unknownLineId;
    if (l.quantity > poLine.outstandingQuantity) {
      return GoodsReceiptError.exceedsOutstanding;
    }
  }
  return null;
}
