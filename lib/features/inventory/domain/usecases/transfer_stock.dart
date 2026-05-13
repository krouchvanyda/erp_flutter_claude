import '../../../../core/error/failure.dart';
import '../../../../core/utils/clock.dart';
import '../entities/inventory_item.dart';
import '../entities/stock_movement.dart';
import '../repositories/items_repository.dart';
import '../repositories/stock_movements_repository.dart';

/// Two-leg result: one row per location.
class TransferStockResult {
  const TransferStockResult({
    required this.sourceItem,
    required this.destinationItem,
    required this.outboundMovement,
    required this.inboundMovement,
  });

  final InventoryItem sourceItem;
  final InventoryItem destinationItem;

  /// Movement on the source row (negative `quantity`).
  final StockMovement outboundMovement;

  /// Movement on the destination row (positive `quantity`).
  final StockMovement inboundMovement;
}

/// Stock transfer between two location bins (Slice 5.2.3).
///
/// **Why two legs**: each [`InventoryItem`] in the catalog is keyed
/// by (sku, warehouse, location). A transfer is one item with the
/// same sku in two different bins. We post **two** ledger rows so
/// the per-location history reads honestly — the source loses N, the
/// destination gains N, both reference the same transfer correlation
/// id.
///
/// **Invariants**:
///   - Source and destination must be different items.
///   - Quantity > 0.
///   - Source on-hand >= quantity (no negative balance).
///   - Both items must be `active`.
///   - Source and destination should typically share the same SKU.
///     We don't enforce that here (in case warehouse staff re-bin into
///     a different sku for repackaging), but a stricter caller can
///     pre-check.
class TransferStockUseCase {
  TransferStockUseCase({
    required ItemsRepository itemsRepository,
    required StockMovementsRepository movementsRepository,
    Clock? clock,
  })  : _items = itemsRepository,
        _movements = movementsRepository,
        _clock = clock ?? DateTime.now;

  final ItemsRepository _items;
  final StockMovementsRepository _movements;
  final Clock _clock;

  Future<TransferStockResult> call({
    required String sourceItemId,
    required String destinationItemId,
    required num quantity,
    String? reference,
    String? note,
  }) async {
    if (sourceItemId == destinationItemId) {
      throw const Failure.validation(
        fieldErrors: {
          'destinationItemId': ['same_as_source'],
        },
      );
    }
    if (quantity <= 0) {
      throw const Failure.validation(
        fieldErrors: {
          'quantity': ['must_be_positive'],
        },
      );
    }

    final src = await _items.findById(sourceItemId);
    if (src == null) {
      throw Failure.notFound(message: 'source item $sourceItemId');
    }
    final dst = await _items.findById(destinationItemId);
    if (dst == null) {
      throw Failure.notFound(message: 'destination item $destinationItemId');
    }

    if (src.status != InventoryItemStatus.active ||
        dst.status != InventoryItemStatus.active) {
      throw Failure.conflict(
        message: 'Both ends of a transfer must be active',
      );
    }
    if (src.onHandQty < quantity) {
      throw const Failure.validation(
        fieldErrors: {
          'quantity': ['exceeds_on_hand'],
        },
      );
    }

    final nextSrc = src.onHandQty - quantity;
    final nextDst = dst.onHandQty + quantity;

    final updatedSrc = await _items.setOnHand(src.id, nextSrc);
    final updatedDst = await _items.setOnHand(dst.id, nextDst);

    final ts = _clock();
    final correlation = reference ?? 'TRF-${ts.microsecondsSinceEpoch}';
    final outbound = await _movements.append(StockMovement(
      id: 'tmp',
      itemId: src.id,
      postedAt: ts,
      type: StockMovementType.transfer,
      quantity: -quantity,
      runningQty: nextSrc,
      reference: correlation,
      note: note,
    ));
    final inbound = await _movements.append(StockMovement(
      id: 'tmp',
      itemId: dst.id,
      postedAt: ts,
      type: StockMovementType.transfer,
      quantity: quantity,
      runningQty: nextDst,
      reference: correlation,
      note: note,
    ));

    return TransferStockResult(
      sourceItem: updatedSrc,
      destinationItem: updatedDst,
      outboundMovement: outbound,
      inboundMovement: inbound,
    );
  }
}
