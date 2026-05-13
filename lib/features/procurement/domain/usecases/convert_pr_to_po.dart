import '../entities/purchase_order.dart';
import '../entities/purchase_request.dart';

/// Result of [convertPurchaseRequestToOrder]. Encodes the two ways
/// conversion can refuse: wrong status, or missing vendor binding.
enum ConvertPurchaseRequestResult { ok, notApproved, vendorMissing }

/// Pure-Dart conversion (Slice 4.2.2). Maps an approved PR's lines
/// 1:1 onto a freshly minted PO. The repo layer assigns the PO id +
/// number on persistence; this builder just produces the in-memory
/// draft + the next state for the source PR.
({
  ConvertPurchaseRequestResult result,
  PurchaseOrder? draftPo,
  PurchaseRequest? updatedPr,
}) convertPurchaseRequestToOrder(
  PurchaseRequest pr, {
  required String vendorId,
  required String vendorName,
  required DateTime expectedAt,
}) {
  if (pr.status != PurchaseRequestStatus.approved) {
    return (
      result: ConvertPurchaseRequestResult.notApproved,
      draftPo: null,
      updatedPr: null,
    );
  }
  if (vendorId.trim().isEmpty || vendorName.trim().isEmpty) {
    return (
      result: ConvertPurchaseRequestResult.vendorMissing,
      draftPo: null,
      updatedPr: null,
    );
  }

  final lines = <PurchaseOrderLine>[
    for (var i = 0; i < pr.lineItems.length; i++)
      PurchaseOrderLine(
        id: 'tmp-li-${i + 1}',
        description: pr.lineItems[i].description,
        sku: pr.lineItems[i].sku,
        orderedQuantity: pr.lineItems[i].quantity,
        receivedQuantity: 0,
        unitPrice: pr.lineItems[i].unitPrice,
        lineTotal: pr.lineItems[i].lineTotal,
      ),
  ];

  final draftPo = PurchaseOrder(
    id: 'tmp', // overwritten on persist
    number: 'PO-tmp', // overwritten on persist
    vendorId: vendorId,
    vendorName: vendorName,
    createdAt: DateTime.now().toUtc(),
    expectedAt: expectedAt,
    status: PurchaseOrderStatus.open,
    totalAmount: pr.totalAmount,
    lineItems: lines,
    sourcePurchaseRequestId: pr.id,
  );

  return (
    result: ConvertPurchaseRequestResult.ok,
    draftPo: draftPo,
    updatedPr: pr.copyWith(status: PurchaseRequestStatus.converted),
  );
}
