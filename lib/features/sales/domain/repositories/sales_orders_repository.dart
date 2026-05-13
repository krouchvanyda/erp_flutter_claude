import '../entities/sales_order.dart';

abstract class SalesOrdersRepository {
  Future<List<SalesOrder>> getAll();
  Stream<List<SalesOrder>> watchAll();
  Future<SalesOrder?> findById(String id);

  /// Persists a freshly created order (Slice 6.2.2 conversion).
  Future<SalesOrder> create(SalesOrder draft);

  /// Advances the fulfillment state machine (Slice 6.2.3).
  Future<SalesOrder> setStatus(
    String id,
    SalesOrderStatus next, {
    DateTime? shippedAt,
    DateTime? deliveredAt,
    String? trackingReference,
  });
}
