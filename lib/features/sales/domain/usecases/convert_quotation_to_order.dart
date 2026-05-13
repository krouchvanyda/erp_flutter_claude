import '../entities/sales_order.dart';
import '../entities/sales_quotation.dart';

/// Result codes for [convertQuotationToOrder] (Slice 6.2.2).
enum ConvertQuotationResult { ok, notAccepted, alreadyConverted, expired }

/// Pure conversion from a [SalesQuotation] to a [SalesOrder] draft
/// (Slice 6.2.2). Mirrors [`convertPurchaseRequestToOrder`] in shape:
/// line items map 1:1; the repo layer assigns the order id + number
/// on persistence.
///
/// **Invariants**:
///   - Quotation status must be `accepted`. `draft` / `sent` /
///     `rejected` / `expired` refuse; `converted` short-circuits.
///   - Caller passes the actioning timestamp so the produced order
///     uses a deterministic `createdAt` (helps tests + audit).
({
  ConvertQuotationResult result,
  SalesOrder? draftOrder,
  SalesQuotation? updatedQuotation,
}) convertQuotationToOrder(
  SalesQuotation quotation, {
  required DateTime now,
}) {
  if (quotation.status == QuotationStatus.converted) {
    return (
      result: ConvertQuotationResult.alreadyConverted,
      draftOrder: null,
      updatedQuotation: null,
    );
  }
  if (quotation.status == QuotationStatus.expired) {
    return (
      result: ConvertQuotationResult.expired,
      draftOrder: null,
      updatedQuotation: null,
    );
  }
  if (quotation.status != QuotationStatus.accepted) {
    return (
      result: ConvertQuotationResult.notAccepted,
      draftOrder: null,
      updatedQuotation: null,
    );
  }

  final lines = <SalesLineItem>[
    for (var i = 0; i < quotation.lineItems.length; i++)
      SalesLineItem(
        id: 'tmp-li-${i + 1}',
        description: quotation.lineItems[i].description,
        sku: quotation.lineItems[i].sku,
        quantity: quotation.lineItems[i].quantity,
        unitPrice: quotation.lineItems[i].unitPrice,
        lineTotal: quotation.lineItems[i].lineTotal,
      ),
  ];

  final draft = SalesOrder(
    id: 'tmp', // overwritten on persist
    number: 'SO-tmp', // overwritten on persist
    customerId: quotation.customerId,
    customerName: quotation.customerName,
    createdAt: now,
    status: SalesOrderStatus.pending,
    totalAmount: quotation.totalAmount,
    lineItems: lines,
    sourceQuotationId: quotation.id,
  );

  return (
    result: ConvertQuotationResult.ok,
    draftOrder: draft,
    updatedQuotation:
        quotation.copyWith(status: QuotationStatus.converted),
  );
}
