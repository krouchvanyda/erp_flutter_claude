import 'package:erp_mobile/features/sales/domain/entities/sales_order.dart';
import 'package:erp_mobile/features/sales/domain/entities/sales_quotation.dart';
import 'package:erp_mobile/features/sales/domain/usecases/revenue_by_period.dart';
import 'package:test/test.dart';

SalesOrder _o({
  required String id,
  required DateTime createdAt,
  required String total,
  SalesOrderStatus status = SalesOrderStatus.delivered,
}) =>
    SalesOrder(
      id: id,
      number: id,
      customerId: 'c',
      customerName: 'C',
      createdAt: createdAt,
      status: status,
      totalAmount: total,
      lineItems: const <SalesLineItem>[],
    );

void main() {
  group('revenueByPeriod — monthly', () {
    test('sums orders into their containing month', () {
      final from = DateTime.utc(2026, 1, 1);
      final to = DateTime.utc(2026, 4, 1);
      final buckets = revenueByPeriod(
        [
          _o(id: '1', createdAt: DateTime.utc(2026, 1, 15), total: r'$100'),
          _o(id: '2', createdAt: DateTime.utc(2026, 1, 28), total: r'$50'),
          _o(id: '3', createdAt: DateTime.utc(2026, 3, 4), total: r'$1,000'),
        ],
        period: RevenuePeriod.monthly,
        from: from,
        to: to,
      );
      expect(buckets, hasLength(3));
      expect(buckets[0].start, DateTime.utc(2026, 1, 1));
      expect(buckets[0].amount, 150);
      expect(buckets[1].start, DateTime.utc(2026, 2, 1));
      expect(buckets[1].amount, 0, reason: 'February has no orders');
      expect(buckets[2].start, DateTime.utc(2026, 3, 1));
      expect(buckets[2].amount, 1000);
    });

    test('excludes cancelled orders', () {
      final buckets = revenueByPeriod(
        [
          _o(
            id: '1',
            createdAt: DateTime.utc(2026, 5, 10),
            total: r'$100',
          ),
          _o(
            id: '2',
            createdAt: DateTime.utc(2026, 5, 11),
            total: r'$1,000',
            status: SalesOrderStatus.cancelled,
          ),
        ],
        period: RevenuePeriod.monthly,
        from: DateTime.utc(2026, 5, 1),
        to: DateTime.utc(2026, 6, 1),
      );
      expect(buckets.single.amount, 100);
    });

    test('orders outside [from, to) are ignored', () {
      final buckets = revenueByPeriod(
        [
          _o(id: '1', createdAt: DateTime.utc(2025, 12, 31), total: r'$1'),
          _o(id: '2', createdAt: DateTime.utc(2026, 1, 1), total: r'$2'),
          _o(id: '3', createdAt: DateTime.utc(2026, 2, 1), total: r'$3'),
        ],
        period: RevenuePeriod.monthly,
        from: DateTime.utc(2026, 1, 1),
        to: DateTime.utc(2026, 2, 1),
      );
      expect(buckets, hasLength(1));
      expect(buckets.single.amount, 2);
    });

    test('year boundary wraps correctly', () {
      final buckets = revenueByPeriod(
        const [],
        period: RevenuePeriod.monthly,
        from: DateTime.utc(2025, 12, 1),
        to: DateTime.utc(2026, 2, 1),
      );
      expect(buckets.map((b) => b.start), [
        DateTime.utc(2025, 12, 1),
        DateTime.utc(2026, 1, 1),
      ]);
    });
  });

  group('revenueByPeriod — weekly', () {
    test('snaps every order to its Monday', () {
      // 2026-05-13 is a Wednesday — bucket should be Monday 2026-05-11.
      final buckets = revenueByPeriod(
        [
          _o(id: '1', createdAt: DateTime.utc(2026, 5, 13), total: r'$100'),
          _o(id: '2', createdAt: DateTime.utc(2026, 5, 17), total: r'$50'),
        ],
        period: RevenuePeriod.weekly,
        from: DateTime.utc(2026, 5, 11),
        to: DateTime.utc(2026, 5, 18),
      );
      expect(buckets, hasLength(1));
      expect(buckets.single.start.weekday, DateTime.monday);
      expect(buckets.single.amount, 150);
    });
  });

  test('to <= from returns empty', () {
    final buckets = revenueByPeriod(
      const [],
      period: RevenuePeriod.monthly,
      from: DateTime.utc(2026, 1, 1),
      to: DateTime.utc(2026, 1, 1),
    );
    expect(buckets, isEmpty);
  });

  test('malformed amount strings sort as zero (no crash)', () {
    final buckets = revenueByPeriod(
      [_o(id: 'broken', createdAt: DateTime.utc(2026, 5, 1), total: '???')],
      period: RevenuePeriod.monthly,
      from: DateTime.utc(2026, 5, 1),
      to: DateTime.utc(2026, 6, 1),
    );
    expect(buckets.single.amount, 0);
  });
}
