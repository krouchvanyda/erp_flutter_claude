import 'dart:async';

import '../../domain/entities/sales_order.dart';
import '../../domain/repositories/sales_orders_repository.dart';
import '../sales_seed.dart';

class StubSalesOrdersRepository implements SalesOrdersRepository {
  StubSalesOrdersRepository();

  static final List<SalesOrder> _seed =
      List<SalesOrder>.of(SalesSeed.orders);
  static int _idCounter = 100;

  final StreamController<List<SalesOrder>> _changes =
      StreamController<List<SalesOrder>>.broadcast();

  @override
  Future<List<SalesOrder>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<SalesOrder>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<SalesOrder?> findById(String id) async {
    for (final o in _seed) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  Future<SalesOrder> create(SalesOrder draft) async {
    _idCounter++;
    final id = 'so-2026-${_idCounter.toString().padLeft(3, '0')}';
    final persisted = draft.copyWith(id: id, number: id.toUpperCase());
    _seed.insert(0, persisted);
    _changes.add(List.unmodifiable(_seed));
    return persisted;
  }

  @override
  Future<SalesOrder> setStatus(
    String id,
    SalesOrderStatus next, {
    DateTime? shippedAt,
    DateTime? deliveredAt,
    String? trackingReference,
  }) async {
    final idx = _seed.indexWhere((o) => o.id == id);
    if (idx == -1) throw StateError('Order "$id" not found');
    _seed[idx] = _seed[idx].copyWith(
      status: next,
      shippedAt: shippedAt ?? _seed[idx].shippedAt,
      deliveredAt: deliveredAt ?? _seed[idx].deliveredAt,
      trackingReference: trackingReference ?? _seed[idx].trackingReference,
    );
    _changes.add(List.unmodifiable(_seed));
    return _seed[idx];
  }
}
