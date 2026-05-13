import 'dart:convert';

import '../../../../core/database/sync_queue_dao.dart';
import '../../../../core/sync/sync_op_type.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/stock_movements_repository.dart';
import '../datasources/items_dao.dart';
import '../inventory_seed.dart';

/// Drift-backed [`StockMovementsRepository`] (Slice 5.3.1).
///
/// **Append-only ledger** — the only mutation is [append], which the
/// DAO inserts and the SyncQueue picks up (Slice 5.3.2). The repo
/// also seeds [`InventorySeed.movements`] once the parent items have
/// landed, so the detail view has history out of the box.
class DriftStockMovementsRepository implements StockMovementsRepository {
  DriftStockMovementsRepository({
    required ItemsDao dao,
    required SyncQueueDao syncQueue,
  })  : _dao = dao,
        _syncQueue = syncQueue;

  final ItemsDao _dao;
  final SyncQueueDao _syncQueue;
  Future<void>? _bootstrap;
  static int _idCounter = 100;

  Future<void> _ensureBootstrapped() {
    return _bootstrap ??= _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    // Movements seed depends on items being present — if items haven't
    // been seeded yet (race between two repos hitting first call), the
    // FK would explode. Defensive: re-check parent existence per row.
    final seed = InventorySeed.movements();
    for (final m in seed) {
      final parent = await _dao.findItemById(m.itemId);
      if (parent == null) continue;
      // Skip duplicates on app restart.
      final existing = await _dao.movementsForItem(m.itemId);
      if (existing.any((e) => e.id == m.id)) continue;
      await _dao.appendMovement(m);
    }
  }

  @override
  Future<List<StockMovement>> forItem(String itemId) async {
    await _ensureBootstrapped();
    return _dao.movementsForItem(itemId);
  }

  @override
  Stream<List<StockMovement>> watchForItem(String itemId) async* {
    await _ensureBootstrapped();
    yield* _dao.watchMovementsForItem(itemId);
  }

  @override
  Future<StockMovement> append(StockMovement draft) async {
    await _ensureBootstrapped();
    _idCounter++;
    final assignedId =
        draft.id == 'tmp' ? 'mov-${DateTime.now().microsecondsSinceEpoch}-$_idCounter' : draft.id;
    final persisted = StockMovement(
      id: assignedId,
      itemId: draft.itemId,
      postedAt: draft.postedAt,
      type: draft.type,
      quantity: draft.quantity,
      runningQty: draft.runningQty,
      reference: draft.reference,
      note: draft.note,
    );
    await _dao.appendMovement(persisted);
    await _enqueueSyncOp(persisted);
    return persisted;
  }

  Future<void> _enqueueSyncOp(StockMovement m) async {
    try {
      await _syncQueue.enqueue(
        entityType: 'inventory.movement',
        entityId: m.id,
        // Append-only; semantically `create` even though SyncOpType
        // is a coarse vocabulary. The replay endpoint POSTs.
        operation: SyncOpType.create,
        payloadJson: jsonEncode({
          'item_id': m.itemId,
          'posted_at': m.postedAt.toUtc().toIso8601String(),
          'type': m.type.name,
          'quantity': m.quantity,
          'running_qty': m.runningQty,
          'reference': m.reference,
          'note': m.note,
        }),
        endpointMethod: 'POST',
        endpointPath: '/inventory/movements',
      );
    } catch (_) {
      // Best-effort enqueue (see DriftInvoicesRepository).
    }
  }
}
