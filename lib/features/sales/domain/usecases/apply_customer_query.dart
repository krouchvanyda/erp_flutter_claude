import '../entities/customer.dart';

/// Pure filter + sort over the customer list (Slice 6.1.1).
List<Customer> applyCustomerQuery(
  List<Customer> all, {
  Set<CustomerStatus> statusFilter = const {},
  Set<CustomerSegment> segmentFilter = const {},
  String searchQuery = '',
  CustomerSort sort = CustomerSort.nameAsc,
}) {
  Iterable<Customer> result = all;

  if (statusFilter.isNotEmpty) {
    result = result.where((c) => statusFilter.contains(c.status));
  }
  if (segmentFilter.isNotEmpty) {
    result = result.where((c) => segmentFilter.contains(c.segment));
  }

  final q = searchQuery.trim().toLowerCase();
  if (q.isNotEmpty) {
    result = result.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.email.toLowerCase().contains(q) ||
        (c.industry?.toLowerCase().contains(q) ?? false));
  }

  final list = result.toList();
  switch (sort) {
    case CustomerSort.nameAsc:
      list.sort((a, b) => a.name.compareTo(b.name));
    case CustomerSort.lifetimeValueDesc:
      // Pre-formatted strings — strip non-digits before comparing so
      // `r'$8,400.00'` sorts above `r'$640.00'` correctly.
      num parse(String v) {
        final cleaned = v.replaceAll(RegExp(r'[^0-9.\-]'), '');
        return num.tryParse(cleaned) ?? 0;
      }

      list.sort(
          (a, b) => parse(b.lifetimeValue).compareTo(parse(a.lifetimeValue)));
    case CustomerSort.recentlyAdded:
      list.sort((a, b) => b.onboardedAt.compareTo(a.onboardedAt));
  }
  return list;
}
