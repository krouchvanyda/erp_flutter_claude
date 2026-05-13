import '../../../../core/error/failure.dart';
import '../../../../core/utils/clock.dart';
import '../entities/inventory_item.dart';
import '../entities/stock_movement.dart';
import '../repositories/items_repository.dart';
import '../repositories/stock_movements_repository.dart';

/// Result bundle from a successful [RecordStockMovementUseCase] call —
/// callers usually want both the updated item (to refresh the list)
/// and the appended movement (to navigate to the audit row).
class RecordStockMovementResult {
  const RecordStockMovementResult({required this.item, required this.movement});
  final InventoryItem item;
  final StockMovement movement;
}

/// Posts a single ledger row + updates the item's on-hand quantity
/// (Slice 5.2.2). Handles every non-transfer movement type:
/// `receipt`, `issue`, `adjustment`. Transfers go through
/// [`TransferStockUseCase`] because they touch two locations.
///
/// **Invariants**:
///   - `quantity` must be `> 0` for receipts and issues
///     (use `adjustment` for signed corrections).
///   - An `issue` whose quantity exceeds on-hand throws
///     [`ValidationFailure`] with field `quantity: ['exceeds_on_hand']`
///     so the form can surface an inline error.
///   - Discontinued / blocked items refuse new receipts but allow
///     adjustments (the latter is the only way to wind them down).
class RecordStockMovementUseCase {
  RecordStockMovementUseCase({
    required ItemsRepository itemsRepository,
    required StockMovementsRepository movementsRepository,
    Clock? clock,
  })  : _items = itemsRepository,
        _movements = movementsRepository,
        _clock = clock ?? DateTime.now;

  final ItemsRepository _items;
  final StockMovementsRepository _movements;
  final Clock _clock;

  Future<RecordStockMovementResult> call({
    required String itemId,
    required StockMovementType type,
    required num quantity,
    String? reference,
    String? note,
  }) async {
    if (type == StockMovementType.transfer) {
      throw Failure.validation(
        message: 'Use TransferStockUseCase for transfers',
        fieldErrors: const {
          'type': ['use_transfer_usecase'],
        },
      );
    }

    final item = await _items.findById(itemId);
    if (item == null) {
      throw Failure.notFound(message: 'item $itemId');
    }

    if (type == StockMovementType.receipt &&
        item.status != InventoryItemStatus.active) {
      throw Failure.conflict(
        message: 'Receipts blocked for ${item.status.name} items',
      );
    }

    if (type == StockMovementType.receipt || type == StockMovementType.issue) {
      if (quantity <= 0) {
        throw const Failure.validation(
          fieldErrors: {
            'quantity': ['must_be_positive'],
          },
        );
      }
    }

    final delta = switch (type) {
      StockMovementType.receipt => quantity,
      StockMovementType.issue => -quantity,
      StockMovementType.adjustment => quantity, // signed
      StockMovementType.transfer => 0, // unreachable
    };

    final nextOnHand = item.onHandQty + delta;
    if (nextOnHand < 0) {
      throw const Failure.validation(
        fieldErrors: {
          'quantity': ['exceeds_on_hand'],
        },
      );
    }

    final updatedItem = await _items.setOnHand(itemId, nextOnHand);
    final persistedMovement = await _movements.append(StockMovement(
      id: 'tmp', // overwritten by repo
      itemId: itemId,
      postedAt: _clock(),
      type: type,
      quantity: quantity.abs(),
      runningQty: nextOnHand,
      reference: reference,
      note: note,
    ));
    return RecordStockMovementResult(
      item: updatedItem,
      movement: persistedMovement,
    );
  }
}
