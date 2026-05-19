import 'dart:convert';

import '../../../../core/database/sync_queue_dao.dart';
import '../../../../core/sync/sync_op_type.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/items_repository.dart';
import '../datasources/items_dao.dart';
import '../inventory_seed.dart';

/// Drift-backed [`ItemsRepository`] (Slice 5.3.1 — spec: "Download
/// item master to local drift DB"). Replaces the stub once the drift
/// schema is at v9.
///
/// **Lazy seed**: on first read, if the table is empty, the bootstrap
/// writes [`InventorySeed.items`]. Mirrors the
/// [`DriftAccountsRepository`] / [`DriftInvoicesRepository`] pattern.
///
/// **SyncQueue integration** (Slice 5.3.2): every [setOnHand] write
/// also enqueues a `PATCH /inventory/items/{id}/on-hand` payload via
/// [`SyncQueueDao`]. The SyncEngine retry path drains the queue on
/// reconnect (Slice 5.3.3).
class DriftItemsRepository implements ItemsRepository {
  DriftItemsRepository({
    required ItemsDao dao,
    required SyncQueueDao syncQueue,
  })  : _dao = dao,
        _syncQueue = syncQueue;

  final ItemsDao _dao;
  final SyncQueueDao _syncQueue;
  Future<void>? _bootstrap;

  Future<void> _ensureBootstrapped() {
    return _bootstrap ??= _seedMissing();
  }

  // Idempotent seed: inserts any [`InventorySeed.items`] whose IDs
  // aren't already in the DB. Lets the seed file pick up new rows
  // (e.g. sibling bins for Slice 5.2.3 Transfer) without overwriting
  // mutable fields on existing items the user has touched.
  Future<void> _seedMissing() async {
    final existing = await _dao.getAllItems();
    final existingIds = existing.map((i) => i.id).toSet();
    final missing = InventorySeed.items
        .where((i) => !existingIds.contains(i.id))
        .toList(growable: false);
    if (missing.isEmpty) return;
    await _dao.upsertItems(missing);
  }

  @override
  Future<List<InventoryItem>> getAll() async {
    await _ensureBootstrapped();
    return _dao.getAllItems();
  }

  @override
  Stream<List<InventoryItem>> watchAll() async* {
    await _ensureBootstrapped();
    yield* _dao.watchAllItems();
  }

  @override
  Future<InventoryItem?> findById(String id) async {
    await _ensureBootstrapped();
    return _dao.findItemById(id);
  }

  @override
  Future<InventoryItem?> findByBarcode(String barcode) async {
    await _ensureBootstrapped();
    return _dao.findItemByBarcode(barcode);
  }

  @override
  Future<List<String>> warehouseCodes() async {
    await _ensureBootstrapped();
    return _dao.distinctWarehouses();
  }

  @override
  Future<InventoryItem> setOnHand(String itemId, num newQty) async {
    await _ensureBootstrapped();
    final updated = await _dao.setOnHand(itemId, newQty);
    await _enqueueSyncOp(
      itemId: itemId,
      endpointPath: '/inventory/items/$itemId/on-hand',
      payload: {'on_hand_qty': newQty},
    );
    return updated;
  }

  Future<void> _enqueueSyncOp({
    required String itemId,
    required String endpointPath,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _syncQueue.enqueue(
        entityType: 'inventory.item',
        entityId: itemId,
        operation: SyncOpType.update,
        payloadJson: jsonEncode(payload),
        endpointMethod: 'PATCH',
        endpointPath: endpointPath,
      );
    } catch (_) {
      // Best-effort enqueue — see the DriftInvoicesRepository note.
    }
  }
}
