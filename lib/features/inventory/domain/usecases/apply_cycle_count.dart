import '../../../../core/error/failure.dart';
import '../../../../core/utils/clock.dart';
import '../entities/cycle_count.dart';
import '../entities/inventory_item.dart';
import '../entities/stock_movement.dart';
import '../repositories/items_repository.dart';
import '../repositories/stock_movements_repository.dart';

/// Result of applying a cycle count (Slice 5.2.4).
class ApplyCycleCountResult {
  const ApplyCycleCountResult({
    required this.adjustmentsPosted,
    required this.totalVariance,
  });

  /// One entry per *non-zero-variance* line — zero-variance lines
  /// don't produce ledger noise.
  final List<StockMovement> adjustmentsPosted;

  /// Sum of `|variance|` across all lines — used as a sanity number
  /// in the success snackbar ("posted 14 unit adjustments").
  final num totalVariance;
}

/// Applies a [CycleCount] by posting one `adjustment` ledger row per
/// non-zero-variance line + updating each item's on-hand (Slice 5.2.4).
///
/// **Invariants**:
///   - The count must not already be completed (rerunning would
///     double-count the variance).
///   - Every line must reference a known item.
///   - Counted quantities must be non-negative.
///
/// **Idempotency note**: this UseCase mutates the items repo and
/// appends movements. The caller (UI / sync engine) is responsible
/// for not invoking it twice for the same `CycleCount.id` — the
/// completedAt timestamp on the persisted cycle count is the natural
/// guard once 5.2.4 has its own repo.
class ApplyCycleCountUseCase {
  ApplyCycleCountUseCase({
    required ItemsRepository itemsRepository,
    required StockMovementsRepository movementsRepository,
    Clock? clock,
  })  : _items = itemsRepository,
        _movements = movementsRepository,
        _clock = clock ?? DateTime.now;

  final ItemsRepository _items;
  final StockMovementsRepository _movements;
  final Clock _clock;

  Future<ApplyCycleCountResult> call(CycleCount count) async {
    if (count.isCompleted) {
      throw const Failure.conflict(message: 'Cycle count already applied');
    }
    if (count.lines.isEmpty) {
      throw const Failure.validation(
        fieldErrors: {
          'lines': ['empty'],
        },
      );
    }
    for (final line in count.lines) {
      if (line.countedQty < 0) {
        throw const Failure.validation(
          fieldErrors: {
            'countedQty': ['must_be_non_negative'],
          },
        );
      }
    }

    final ts = _clock();
    final adjustments = <StockMovement>[];
    num totalVariance = 0;

    for (final line in count.lines) {
      final variance = line.variance;
      if (variance == 0) continue;

      final item = await _items.findById(line.itemId);
      if (item == null) {
        throw Failure.notFound(message: 'item ${line.itemId}');
      }
      // Honour `discontinued` items by writing the adjustment but
      // skipping `blocked` ones — blocked is an admin freeze.
      if (item.status == InventoryItemStatus.blocked) {
        throw Failure.conflict(
          message: 'Blocked items cannot be cycle-adjusted (${item.id})',
        );
      }

      final nextOnHand = item.onHandQty + variance;
      // A cycle count can drive on-hand to 0 but never below — the
      // counter physically saw zero on the shelf.
      if (nextOnHand < 0) {
        throw const Failure.validation(
          fieldErrors: {
            'countedQty': ['exceeds_capacity'],
          },
        );
      }
      await _items.setOnHand(item.id, nextOnHand);
      final movement = await _movements.append(StockMovement(
        id: 'tmp',
        itemId: item.id,
        postedAt: ts,
        type: StockMovementType.adjustment,
        quantity: variance,
        runningQty: nextOnHand,
        reference: count.id,
        note: count.note,
      ));
      adjustments.add(movement);
      totalVariance = totalVariance + variance.abs();
    }

    return ApplyCycleCountResult(
      adjustmentsPosted: adjustments,
      totalVariance: totalVariance,
    );
  }
}
