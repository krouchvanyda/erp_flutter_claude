import '../entities/sales_quotation.dart';

/// Pure filter + sort over a quotation list (Slice 6.2.1).
List<SalesQuotation> applyQuotationQuery(
  List<SalesQuotation> all, {
  Set<QuotationStatus> statusFilter = const {},
  String searchQuery = '',
  QuotationSort sort = QuotationSort.createdDesc,
}) {
  Iterable<SalesQuotation> result = all;

  if (statusFilter.isNotEmpty) {
    result = result.where((q) => statusFilter.contains(q.status));
  }
  final q = searchQuery.trim().toLowerCase();
  if (q.isNotEmpty) {
    result = result.where((qu) =>
        qu.number.toLowerCase().contains(q) ||
        qu.customerName.toLowerCase().contains(q));
  }
  final list = result.toList();
  switch (sort) {
    case QuotationSort.createdDesc:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case QuotationSort.createdAsc:
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case QuotationSort.totalDesc:
      list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    case QuotationSort.validityAsc:
      list.sort((a, b) => a.validUntil.compareTo(b.validUntil));
  }
  return list;
}
