import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:erp_mobile/features/inventory/domain/entities/stock_movement.dart';
import 'package:erp_mobile/features/inventory/domain/repositories/items_repository.dart';
import 'package:erp_mobile/features/inventory/domain/repositories/stock_movements_repository.dart';
import 'package:erp_mobile/features/inventory/domain/usecases/record_stock_movement.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockItemsRepo extends Mock implements ItemsRepository {}

class _MockMovementsRepo extends Mock implements StockMovementsRepository {}

InventoryItem _item({
  num onHandQty = 100,
  InventoryItemStatus status = InventoryItemStatus.active,
}) =>
    InventoryItem(
      id: 'inv-1',
      sku: 'WID',
      name: 'Widget',
      warehouseCode: 'WH',
      locationCode: 'A1',
      onHandQty: onHandQty,
      reorderPoint: 10,
      unitCost: r'$1',
      status: status,
    );

StockMovement _fakeMovement() => StockMovement(
      id: 'mov-x',
      itemId: 'inv-1',
      postedAt: DateTime.utc(2026, 5, 13),
      type: StockMovementType.receipt,
      quantity: 1,
      runningQty: 0,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_fakeMovement());
  });

  late _MockItemsRepo items;
  late _MockMovementsRepo movements;
  late RecordStockMovementUseCase usecase;
  final clock = DateTime.utc(2026, 5, 13, 10);

  setUp(() {
    items = _MockItemsRepo();
    movements = _MockMovementsRepo();
    usecase = RecordStockMovementUseCase(
      itemsRepository: items,
      movementsRepository: movements,
      clock: () => clock,
    );
  });

  test('receipt: adds qty + appends a movement with the new runningQty',
      () async {
    when(() => items.findById('inv-1')).thenAnswer((_) async => _item());
    when(() => items.setOnHand('inv-1', 110))
        .thenAnswer((_) async => _item(onHandQty: 110));
    when(() => movements.append(any()))
        .thenAnswer((inv) async => inv.positionalArguments.single as StockMovement);

    final out = await usecase(
      itemId: 'inv-1',
      type: StockMovementType.receipt,
      quantity: 10,
      reference: 'PO-1',
    );
    expect(out.item.onHandQty, 110);
    verify(() => items.setOnHand('inv-1', 110)).called(1);
    final captured =
        verify(() => movements.append(captureAny())).captured.single as StockMovement;
    expect(captured.runningQty, 110);
    expect(captured.type, StockMovementType.receipt);
    expect(captured.postedAt, clock);
    expect(captured.reference, 'PO-1');
  });

  test('issue: subtracts qty', () async {
    when(() => items.findById('inv-1')).thenAnswer((_) async => _item());
    when(() => items.setOnHand('inv-1', 60))
        .thenAnswer((_) async => _item(onHandQty: 60));
    when(() => movements.append(any())).thenAnswer(
        (inv) async => inv.positionalArguments.single as StockMovement);

    final out = await usecase(
      itemId: 'inv-1',
      type: StockMovementType.issue,
      quantity: 40,
    );
    expect(out.item.onHandQty, 60);
  });

  test('issue: refuses to over-issue (ValidationFailure exceeds_on_hand)',
      () async {
    when(() => items.findById('inv-1'))
        .thenAnswer((_) async => _item(onHandQty: 5));
    await expectLater(
      usecase(
        itemId: 'inv-1',
        type: StockMovementType.issue,
        quantity: 10,
      ),
      throwsA(isA<ValidationFailure>().having(
        (f) => f.fieldErrors,
        'fieldErrors',
        containsPair('quantity', ['exceeds_on_hand']),
      )),
    );
    verifyNever(() => items.setOnHand(any(), any()));
  });

  test('receipt: rejects non-positive quantity', () async {
    when(() => items.findById('inv-1')).thenAnswer((_) async => _item());
    await expectLater(
      usecase(
        itemId: 'inv-1',
        type: StockMovementType.receipt,
        quantity: 0,
      ),
      throwsA(isA<ValidationFailure>().having(
        (f) => f.fieldErrors,
        'fieldErrors',
        containsPair('quantity', ['must_be_positive']),
      )),
    );
  });

  test('receipt on a discontinued item → ConflictFailure', () async {
    when(() => items.findById('inv-1')).thenAnswer(
        (_) async => _item(status: InventoryItemStatus.discontinued));
    await expectLater(
      usecase(
        itemId: 'inv-1',
        type: StockMovementType.receipt,
        quantity: 1,
      ),
      throwsA(isA<ConflictFailure>()),
    );
  });

  test('adjustment accepts signed quantities (both directions)', () async {
    when(() => items.findById('inv-1')).thenAnswer((_) async => _item());
    when(() => items.setOnHand('inv-1', 99))
        .thenAnswer((_) async => _item(onHandQty: 99));
    when(() => movements.append(any())).thenAnswer(
        (inv) async => inv.positionalArguments.single as StockMovement);

    await usecase(
      itemId: 'inv-1',
      type: StockMovementType.adjustment,
      quantity: -1,
    );
    verify(() => items.setOnHand('inv-1', 99)).called(1);
  });

  test('unknown id → NotFoundFailure', () async {
    when(() => items.findById('nope')).thenAnswer((_) async => null);
    await expectLater(
      usecase(
        itemId: 'nope',
        type: StockMovementType.receipt,
        quantity: 1,
      ),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('transfer type rejected — caller must use TransferStockUseCase',
      () async {
    await expectLater(
      usecase(
        itemId: 'inv-1',
        type: StockMovementType.transfer,
        quantity: 1,
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
