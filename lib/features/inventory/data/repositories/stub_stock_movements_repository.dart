import 'dart:async';

import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/stock_movements_repository.dart';
import '../inventory_seed.dart';

/// In-memory ledger (Slice 5.1.2 + 5.2.x). Stores movements newest-
/// first (consumers expect descending postedAt) so the read path is
/// just an unmodifiable view.
class StubStockMovementsRepository implements StockMovementsRepository {
  StubStockMovementsRepository();

  static final List<StockMovement> _seed = List<StockMovement>.of(
    InventorySeed.movements(),
  )..sort((a, b) => b.postedAt.compareTo(a.postedAt));

  static int _idCounter = 100;

  final StreamController<List<StockMovement>> _changes =
      StreamController<List<StockMovement>>.broadcast();

  @override
  Future<List<StockMovement>> forItem(String itemId) async {
    return _seed.where((m) => m.itemId == itemId).toList(growable: false);
  }

  @override
  Stream<List<StockMovement>> watchForItem(String itemId) async* {
    yield await forItem(itemId);
    yield* _changes.stream
        .map((all) => all.where((m) => m.itemId == itemId).toList());
  }

  @override
  Future<StockMovement> append(StockMovement draft) async {
    _idCounter++;
    final persisted = StockMovement(
      id: 'mov-${_idCounter.toString().padLeft(3, '0')}',
      itemId: draft.itemId,
      postedAt: draft.postedAt,
      type: draft.type,
      quantity: draft.quantity,
      runningQty: draft.runningQty,
      reference: draft.reference,
      note: draft.note,
    );
    _seed.insert(0, persisted);
    _changes.add(List.unmodifiable(_seed));
    return persisted;
  }
}
