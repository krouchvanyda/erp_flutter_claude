import 'package:erp_mobile/features/sales/domain/entities/sales_order.dart';
import 'package:erp_mobile/features/sales/domain/entities/sales_quotation.dart';
import 'package:erp_mobile/features/sales/domain/usecases/top_rankings.dart';
import 'package:test/test.dart';

SalesOrder _o({
  required String id,
  String customerId = 'c-1',
  String customerName = 'Acme',
  String total = r'$100.00',
  SalesOrderStatus status = SalesOrderStatus.delivered,
  List<SalesLineItem> lines = const [],
}) =>
    SalesOrder(
      id: id,
      number: id,
      customerId: customerId,
      customerName: customerName,
      createdAt: DateTime.utc(2026, 5, 1),
      status: status,
      totalAmount: total,
      lineItems: lines,
    );

void main() {
  group('topCustomers', () {
    test('sums per customer, sorts desc, takes top N', () {
      final out = topCustomers(
        [
          _o(id: '1', customerId: 'a', customerName: 'A', total: r'$100'),
          _o(id: '2', customerId: 'a', customerName: 'A', total: r'$200'),
          _o(id: '3', customerId: 'b', customerName: 'B', total: r'$500'),
          _o(id: '4', customerId: 'c', customerName: 'C', total: r'$50'),
        ],
        limit: 2,
      );
      expect(out, hasLength(2));
      expect(out.first.key, 'b');
      expect(out.first.label, 'B');
      expect(out.first.amount, r'$500.00');
      expect(out.first.units, 1);
      expect(out.last.key, 'a');
      expect(out.last.units, 2);
    });

    test('cancelled orders excluded', () {
      final out = topCustomers([
        _o(id: '1', customerId: 'a', total: r'$100'),
        _o(
          id: '2',
          customerId: 'a',
          total: r'$1,000',
          status: SalesOrderStatus.cancelled,
        ),
      ]);
      expect(out.single.amount, r'$100.00');
    });

    test('empty input → empty output', () {
      expect(topCustomers(const []), isEmpty);
    });
  });

  group('topProducts', () {
    SalesLineItem li({
      required String id,
      String? sku,
      required String description,
      required num qty,
      required String lineTotal,
    }) =>
        SalesLineItem(
          id: id,
          description: description,
          sku: sku,
          quantity: qty,
          unitPrice: r'$1',
          lineTotal: lineTotal,
        );

    test('keys on SKU when present, descriptions otherwise', () {
      final out = topProducts([
        _o(id: '1', total: r'$200', lines: [
          li(id: 'l1', sku: 'A', description: 'Apple', qty: 2, lineTotal: r'$200'),
        ]),
        _o(id: '2', total: r'$50', lines: [
          li(id: 'l2', description: 'Banana', qty: 5, lineTotal: r'$50'),
        ]),
      ]);
      expect(out, hasLength(2));
      expect(out.first.key, 'A');
      expect(out.first.label, contains('Apple'));
      expect(out.last.key, 'Banana');
    });

    test('aggregates units across orders', () {
      final out = topProducts([
        _o(id: '1', total: r'$30', lines: [
          li(id: 'l1', sku: 'X', description: 'X', qty: 3, lineTotal: r'$30'),
        ]),
        _o(id: '2', total: r'$50', lines: [
          li(id: 'l2', sku: 'X', description: 'X', qty: 5, lineTotal: r'$50'),
        ]),
      ]);
      expect(out.single.units, 8);
      expect(out.single.amount, r'$80.00');
    });

    test('cancelled order contributes nothing', () {
      final out = topProducts([
        _o(
          id: '1',
          status: SalesOrderStatus.cancelled,
          total: r'$1,000',
          lines: [
            li(id: 'l1', sku: 'X', description: 'X', qty: 10, lineTotal: r'$1,000'),
          ],
        ),
      ]);
      expect(out, isEmpty);
    });
  });
}
