import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:erp_mobile/features/inventory/domain/entities/stock_movement.dart';
import 'package:erp_mobile/features/inventory/domain/repositories/items_repository.dart';
import 'package:erp_mobile/features/inventory/domain/repositories/stock_movements_repository.dart';
import 'package:erp_mobile/features/inventory/domain/usecases/transfer_stock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockItemsRepo extends Mock implements ItemsRepository {}

class _MockMovementsRepo extends Mock implements StockMovementsRepository {}

InventoryItem _item({
  required String id,
  num onHandQty = 50,
  InventoryItemStatus status = InventoryItemStatus.active,
}) =>
    InventoryItem(
      id: id,
      sku: 'WID',
      name: 'Widget',
      warehouseCode: 'WH',
      locationCode: id,
      onHandQty: onHandQty,
      reorderPoint: 5,
      unitCost: r'$1',
      status: status,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(StockMovement(
      id: 'x',
      itemId: 'x',
      postedAt: DateTime.utc(2026, 5, 13),
      type: StockMovementType.transfer,
      quantity: 1,
      runningQty: 0,
    ));
  });

  late _MockItemsRepo items;
  late _MockMovementsRepo movements;
  late TransferStockUseCase usecase;
  final clock = DateTime.utc(2026, 5, 13, 10);

  setUp(() {
    items = _MockItemsRepo();
    movements = _MockMovementsRepo();
    usecase = TransferStockUseCase(
      itemsRepository: items,
      movementsRepository: movements,
      clock: () => clock,
    );
  });

  test('happy path — two legs, opposing signs, same reference', () async {
    when(() => items.findById('src'))
        .thenAnswer((_) async => _item(id: 'src', onHandQty: 30));
    when(() => items.findById('dst'))
        .thenAnswer((_) async => _item(id: 'dst', onHandQty: 10));
    when(() => items.setOnHand('src', 20))
        .thenAnswer((_) async => _item(id: 'src', onHandQty: 20));
    when(() => items.setOnHand('dst', 20))
        .thenAnswer((_) async => _item(id: 'dst', onHandQty: 20));
    when(() => movements.append(any())).thenAnswer(
        (inv) async => inv.positionalArguments.single as StockMovement);

    final out = await usecase(
      sourceItemId: 'src',
      destinationItemId: 'dst',
      quantity: 10,
      reference: 'TRF-001',
    );

    expect(out.sourceItem.onHandQty, 20);
    expect(out.destinationItem.onHandQty, 20);
    expect(out.outboundMovement.quantity, -10);
    expect(out.inboundMovement.quantity, 10);
    expect(out.outboundMovement.reference, 'TRF-001');
    expect(out.inboundMovement.reference, 'TRF-001');
    expect(out.outboundMovement.postedAt, clock);
    expect(out.inboundMovement.postedAt, clock);
  });

  test('source == destination → ValidationFailure', () async {
    await expectLater(
      usecase(
        sourceItemId: 'a',
        destinationItemId: 'a',
        quantity: 1,
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('non-positive quantity → ValidationFailure', () async {
    await expectLater(
      usecase(
        sourceItemId: 'a',
        destinationItemId: 'b',
        quantity: 0,
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('exceeds source on-hand → ValidationFailure', () async {
    when(() => items.findById('src'))
        .thenAnswer((_) async => _item(id: 'src', onHandQty: 3));
    when(() => items.findById('dst'))
        .thenAnswer((_) async => _item(id: 'dst'));
    await expectLater(
      usecase(
        sourceItemId: 'src',
        destinationItemId: 'dst',
        quantity: 5,
      ),
      throwsA(isA<ValidationFailure>().having(
        (f) => f.fieldErrors,
        'fieldErrors',
        containsPair('quantity', ['exceeds_on_hand']),
      )),
    );
  });

  test('blocked / discontinued endpoints → ConflictFailure', () async {
    when(() => items.findById('src'))
        .thenAnswer((_) async => _item(id: 'src'));
    when(() => items.findById('dst')).thenAnswer((_) async => _item(
          id: 'dst',
          status: InventoryItemStatus.blocked,
        ));
    await expectLater(
      usecase(
        sourceItemId: 'src',
        destinationItemId: 'dst',
        quantity: 1,
      ),
      throwsA(isA<ConflictFailure>()),
    );
  });

  test('unknown source or destination → NotFoundFailure', () async {
    when(() => items.findById('src')).thenAnswer((_) async => null);
    await expectLater(
      usecase(
        sourceItemId: 'src',
        destinationItemId: 'dst',
        quantity: 1,
      ),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('reference defaults to TRF-<epoch> when caller passes null',
      () async {
    when(() => items.findById('src'))
        .thenAnswer((_) async => _item(id: 'src'));
    when(() => items.findById('dst'))
        .thenAnswer((_) async => _item(id: 'dst'));
    when(() => items.setOnHand('src', 49))
        .thenAnswer((_) async => _item(id: 'src', onHandQty: 49));
    when(() => items.setOnHand('dst', 51))
        .thenAnswer((_) async => _item(id: 'dst', onHandQty: 51));
    when(() => movements.append(any())).thenAnswer(
        (inv) async => inv.positionalArguments.single as StockMovement);

    final out = await usecase(
      sourceItemId: 'src',
      destinationItemId: 'dst',
      quantity: 1,
    );
    expect(out.outboundMovement.reference, startsWith('TRF-'));
    expect(out.outboundMovement.reference, out.inboundMovement.reference);
  });
}
