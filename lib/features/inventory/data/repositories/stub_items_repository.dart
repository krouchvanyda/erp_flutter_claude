import 'dart:async';

import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/items_repository.dart';
import '../inventory_seed.dart';

/// In-memory items master (Slice 5.1.1). Replaced by a drift-backed
/// impl in Slice 5.3.1 — same contract, so the DI swap is mechanical.
class StubItemsRepository implements ItemsRepository {
  StubItemsRepository();

  static final List<InventoryItem> _seed = List<InventoryItem>.of(
    InventorySeed.items,
  );

  final StreamController<List<InventoryItem>> _changes =
      StreamController<List<InventoryItem>>.broadcast();

  @override
  Future<List<InventoryItem>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<InventoryItem>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<InventoryItem?> findById(String id) async {
    for (final i in _seed) {
      if (i.id == id) return i;
    }
    return null;
  }

  @override
  Future<InventoryItem?> findByBarcode(String barcode) async {
    for (final i in _seed) {
      if (i.barcode == barcode) return i;
    }
    return null;
  }

  @override
  Future<List<String>> warehouseCodes() async {
    final set = <String>{};
    for (final i in _seed) {
      set.add(i.warehouseCode);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Future<InventoryItem> setOnHand(String itemId, num newQty) async {
    final idx = _seed.indexWhere((i) => i.id == itemId);
    if (idx == -1) throw StateError('Item "$itemId" not found');
    _seed[idx] = _seed[idx].copyWith(onHandQty: newQty);
    _changes.add(List.unmodifiable(_seed));
    return _seed[idx];
  }
}
