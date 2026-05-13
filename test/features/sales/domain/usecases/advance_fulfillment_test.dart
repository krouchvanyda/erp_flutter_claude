import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/sales/domain/entities/sales_order.dart';
import 'package:erp_mobile/features/sales/domain/usecases/advance_fulfillment.dart';
import 'package:test/test.dart';

SalesOrder _o({SalesOrderStatus status = SalesOrderStatus.pending}) =>
    SalesOrder(
      id: 'o-1',
      number: 'SO-1',
      customerId: 'c-1',
      customerName: 'Acme',
      createdAt: DateTime.utc(2026, 5, 1),
      status: status,
      totalAmount: r'$100.00',
      lineItems: const [],
    );

void main() {
  final now = DateTime.utc(2026, 5, 13, 10);

  group('advanceFulfillment — legal transitions', () {
    test('pending → packing', () {
      final out =
          advanceFulfillment(_o(), to: SalesOrderStatus.packing, now: now);
      expect(out.status, SalesOrderStatus.packing);
      expect(out.shippedAt, isNull);
    });
    test('packing → shipped (requires tracking, stamps shippedAt)', () {
      final out = advanceFulfillment(
        _o(status: SalesOrderStatus.packing),
        to: SalesOrderStatus.shipped,
        now: now,
        trackingReference: 'TR-1',
      );
      expect(out.status, SalesOrderStatus.shipped);
      expect(out.trackingReference, 'TR-1');
      expect(out.shippedAt, now);
    });
    test('shipped → delivered (stamps deliveredAt)', () {
      final out = advanceFulfillment(
        _o(status: SalesOrderStatus.shipped),
        to: SalesOrderStatus.delivered,
        now: now,
      );
      expect(out.status, SalesOrderStatus.delivered);
      expect(out.deliveredAt, now);
    });
    test('pending → cancelled', () {
      final out = advanceFulfillment(
        _o(),
        to: SalesOrderStatus.cancelled,
        now: now,
      );
      expect(out.status, SalesOrderStatus.cancelled);
    });
    test('packing → cancelled', () {
      final out = advanceFulfillment(
        _o(status: SalesOrderStatus.packing),
        to: SalesOrderStatus.cancelled,
        now: now,
      );
      expect(out.status, SalesOrderStatus.cancelled);
    });
  });

  group('advanceFulfillment — illegal transitions', () {
    test('pending → shipped (skips packing)', () {
      expect(
        () => advanceFulfillment(
          _o(),
          to: SalesOrderStatus.shipped,
          now: now,
          trackingReference: 'X',
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });
    test('shipped → cancelled', () {
      expect(
        () => advanceFulfillment(
          _o(status: SalesOrderStatus.shipped),
          to: SalesOrderStatus.cancelled,
          now: now,
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });
    test('delivered → anything', () {
      for (final s in SalesOrderStatus.values) {
        expect(
          () => advanceFulfillment(
            _o(status: SalesOrderStatus.delivered),
            to: s,
            now: now,
            trackingReference: 'X',
          ),
          throwsA(isA<ConflictFailure>()),
        );
      }
    });
    test('cancelled is terminal', () {
      expect(
        () => advanceFulfillment(
          _o(status: SalesOrderStatus.cancelled),
          to: SalesOrderStatus.packing,
          now: now,
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });

  test('shipping without a tracking reference → ValidationFailure', () {
    expect(
      () => advanceFulfillment(
        _o(status: SalesOrderStatus.packing),
        to: SalesOrderStatus.shipped,
        now: now,
      ),
      throwsA(isA<ValidationFailure>()),
    );
    expect(
      () => advanceFulfillment(
        _o(status: SalesOrderStatus.packing),
        to: SalesOrderStatus.shipped,
        now: now,
        trackingReference: '   ',
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
