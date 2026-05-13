import '../entities/invoice.dart';

/// Sort axis for the invoice list (Slice 3.2.1).
enum InvoiceSort {
  issuedDateDesc,
  issuedDateAsc,
  dueDateAsc,
  amountDesc,
  numberAsc,
}

/// Pure-Dart filter + sort + search pipeline (Slice 3.2.1).
///
/// **Why pure**: keeps the matching rules unit-testable without a
/// bloc / widget context, and lets the same pipeline run on the
/// dashboard "open invoices" widget without building a second
/// implementation.
///
/// **Search match**: case-insensitive `contains` against
/// `invoiceNumber` AND `customerName`. Empty / whitespace-only
/// query is a no-op.
///
/// **Sort stability**: `List.sort` is stable in Dart, so equal-key
/// rows preserve insertion order — no jitter when two invoices
/// share an issued date.
List<Invoice> applyInvoiceQuery(
  List<Invoice> source, {
  Set<InvoiceStatus>? statusFilter,
  String? searchQuery,
  InvoiceSort sort = InvoiceSort.issuedDateDesc,
}) {
  Iterable<Invoice> result = source;

  if (statusFilter != null && statusFilter.isNotEmpty) {
    result = result.where((i) => statusFilter.contains(i.status));
  }

  final q = searchQuery?.trim().toLowerCase();
  if (q != null && q.isNotEmpty) {
    result = result.where((i) =>
        i.invoiceNumber.toLowerCase().contains(q) ||
        i.customerName.toLowerCase().contains(q));
  }

  final list = result.toList();
  list.sort(_comparatorFor(sort));
  return list;
}

int Function(Invoice, Invoice) _comparatorFor(InvoiceSort sort) {
  return switch (sort) {
    InvoiceSort.issuedDateDesc => (a, b) => b.issuedAt.compareTo(a.issuedAt),
    InvoiceSort.issuedDateAsc => (a, b) => a.issuedAt.compareTo(b.issuedAt),
    InvoiceSort.dueDateAsc => (a, b) => a.dueAt.compareTo(b.dueAt),
    // Lexicographic on the pre-formatted amount string is wrong
    // ($9.00 > $10.00). Strip non-digits and parse to an int of
    // cents; same locale assumption as the rest of the demo (USD).
    InvoiceSort.amountDesc => (a, b) =>
        _amountCents(b.totalAmount).compareTo(_amountCents(a.totalAmount)),
    InvoiceSort.numberAsc => (a, b) =>
        a.invoiceNumber.compareTo(b.invoiceNumber),
  };
}

/// Strip currency symbol + thousands separators + decimal point and
/// parse as cents. `r'$1,234.56'` → `123456`. Falls back to 0 on
/// non-parseable input rather than throwing — keeps the sort robust
/// to seed-data typos.
int _amountCents(String formatted) {
  final cleaned = formatted.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(cleaned) ?? 0;
}
