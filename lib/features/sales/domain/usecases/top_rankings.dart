import '../entities/sales_order.dart';

/// One row on a "top N" ranking (Slice 6.3.2).
class TopRanking<T> {
  const TopRanking({
    required this.key,
    required this.label,
    required this.amount,
    required this.units,
  });

  /// Stable identifier — `customerId`, sku, or rep id.
  final T key;

  /// Display label captured at compute time so the analytics page
  /// doesn't have to refetch the parent entity.
  final String label;

  /// Pre-formatted total revenue (e.g. `r'$48,200.00'`).
  final String amount;

  /// Raw line-item units (orders, qty, deals — depends on the use case).
  final num units;
}

/// **Top customers** by revenue (Slice 6.3.2). Cancelled orders are
/// excluded — they didn't earn revenue.
List<TopRanking<String>> topCustomers(
  List<SalesOrder> orders, {
  int limit = 5,
}) {
  final revenueById = <String, num>{};
  final nameById = <String, String>{};
  final unitsById = <String, int>{};
  for (final o in orders) {
    if (o.status == SalesOrderStatus.cancelled) continue;
    revenueById[o.customerId] =
        (revenueById[o.customerId] ?? 0) + _parse(o.totalAmount);
    nameById[o.customerId] = o.customerName;
    unitsById[o.customerId] = (unitsById[o.customerId] ?? 0) + 1;
  }
  final entries = revenueById.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in entries.take(limit))
      TopRanking<String>(
        key: e.key,
        label: nameById[e.key] ?? e.key,
        amount: _format(e.value),
        units: unitsById[e.key] ?? 0,
      ),
  ];
}

/// **Top products** by revenue, keyed by SKU when present, else by
/// description (Slice 6.3.2). Each line contributes its `lineTotal` to
/// the SKU's revenue and its `quantity` to the unit count.
List<TopRanking<String>> topProducts(
  List<SalesOrder> orders, {
  int limit = 5,
}) {
  final revenueByKey = <String, num>{};
  final labelByKey = <String, String>{};
  final unitsByKey = <String, num>{};
  for (final o in orders) {
    if (o.status == SalesOrderStatus.cancelled) continue;
    for (final line in o.lineItems) {
      final key = line.sku ?? line.description;
      revenueByKey[key] =
          (revenueByKey[key] ?? 0) + _parse(line.lineTotal);
      labelByKey[key] = line.sku == null
          ? line.description
          : '${line.sku} — ${line.description}';
      unitsByKey[key] = (unitsByKey[key] ?? 0) + line.quantity;
    }
  }
  final entries = revenueByKey.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in entries.take(limit))
      TopRanking<String>(
        key: e.key,
        label: labelByKey[e.key] ?? e.key,
        amount: _format(e.value),
        units: unitsByKey[e.key] ?? 0,
      ),
  ];
}

num _parse(String formatted) {
  final cleaned = formatted.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return num.tryParse(cleaned) ?? 0;
}

String _format(num n) {
  final abs = n.abs().toStringAsFixed(2);
  final parts = abs.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return '${n < 0 ? '-' : ''}\$$buf.${parts[1]}';
}
