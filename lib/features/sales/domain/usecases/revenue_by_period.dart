import '../entities/sales_order.dart';

/// Bucketing granularity for the revenue chart (Slice 6.3.1).
enum RevenuePeriod { weekly, monthly }

/// One bucket on the chart.
class RevenueBucket {
  const RevenueBucket({required this.start, required this.amount});

  /// First day of the bucket in UTC — week-start (Mon) for [weekly];
  /// 1st of the month for [monthly].
  final DateTime start;

  final num amount;
}

/// Pure aggregation (Slice 6.3.1). Sums each [SalesOrder]'s total
/// into the bucket containing its `createdAt`. **Cancelled orders are
/// excluded** — they didn't earn revenue. Buckets are returned in
/// chronological order with no gaps over the full range.
///
/// **Money parsing**: works against the pre-formatted `totalAmount`
/// strings by stripping non-digits before `num.tryParse`. Locale-
/// dependent — the seed is single-currency so this is fine for the
/// demo; when multi-currency lands the entity will carry raw cents.
List<RevenueBucket> revenueByPeriod(
  List<SalesOrder> orders, {
  required RevenuePeriod period,
  required DateTime from,
  required DateTime to,
}) {
  if (!to.isAfter(from)) return const [];

  final keyed = <DateTime, num>{};
  for (final o in orders) {
    if (o.status == SalesOrderStatus.cancelled) continue;
    final ts = o.createdAt;
    if (ts.isBefore(from) || !ts.isBefore(to)) continue;
    final bucket = _bucketFor(ts, period);
    keyed[bucket] = (keyed[bucket] ?? 0) + _parseAmount(o.totalAmount);
  }

  // Fill the whole range so the chart has no gaps.
  final result = <RevenueBucket>[];
  var cursor = _bucketFor(from, period);
  while (cursor.isBefore(to)) {
    result.add(RevenueBucket(
      start: cursor,
      amount: keyed[cursor] ?? 0,
    ));
    cursor = _next(cursor, period);
  }
  return result;
}

DateTime _bucketFor(DateTime ts, RevenuePeriod p) {
  switch (p) {
    case RevenuePeriod.weekly:
      // Snap to Monday in UTC.
      final daysFromMonday = (ts.weekday - DateTime.monday) % 7;
      final monday = DateTime.utc(ts.year, ts.month, ts.day)
          .subtract(Duration(days: daysFromMonday));
      return monday;
    case RevenuePeriod.monthly:
      return DateTime.utc(ts.year, ts.month, 1);
  }
}

DateTime _next(DateTime bucket, RevenuePeriod p) {
  switch (p) {
    case RevenuePeriod.weekly:
      return bucket.add(const Duration(days: 7));
    case RevenuePeriod.monthly:
      final nextMonth = bucket.month == 12 ? 1 : bucket.month + 1;
      final nextYear = bucket.month == 12 ? bucket.year + 1 : bucket.year;
      return DateTime.utc(nextYear, nextMonth, 1);
  }
}

num _parseAmount(String formatted) {
  final cleaned = formatted.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return num.tryParse(cleaned) ?? 0;
}
