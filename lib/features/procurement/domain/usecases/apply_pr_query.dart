import '../entities/purchase_request.dart';

/// Pure filter + sort over a PR list (Slice 4.1.1).
///
/// Mirrors `applyInvoiceQuery` from Slice 3.2.1 — keeps the bloc thin
/// and the business logic exhaustively unit-testable.
List<PurchaseRequest> applyPurchaseRequestQuery(
  List<PurchaseRequest> all, {
  Set<PurchaseRequestStatus> statusFilter = const {},
  String searchQuery = '',
  PurchaseRequestSort sort = PurchaseRequestSort.createdDesc,
}) {
  Iterable<PurchaseRequest> result = all;

  if (statusFilter.isNotEmpty) {
    result = result.where((p) => statusFilter.contains(p.status));
  }

  final q = searchQuery.trim().toLowerCase();
  if (q.isNotEmpty) {
    result = result.where((p) =>
        p.number.toLowerCase().contains(q) ||
        p.requesterName.toLowerCase().contains(q) ||
        p.costCenter.toLowerCase().contains(q));
  }

  final list = result.toList();
  switch (sort) {
    case PurchaseRequestSort.createdDesc:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case PurchaseRequestSort.createdAsc:
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case PurchaseRequestSort.totalDesc:
      // Lexical sort on pre-formatted amounts is wrong for cross-currency
      // — but the seed is single-currency. When real money lands, store
      // a numeric `totalCents` alongside `totalAmount` and sort on that.
      list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    case PurchaseRequestSort.numberAsc:
      list.sort((a, b) => a.number.compareTo(b.number));
  }
  return list;
}
