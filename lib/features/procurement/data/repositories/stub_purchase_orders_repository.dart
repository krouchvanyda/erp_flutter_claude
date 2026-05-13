import '../../domain/entities/goods_receipt.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/repositories/purchase_orders_repository.dart';

/// In-memory PO seed (Slice 4.2.1).
class StubPurchaseOrdersRepository implements PurchaseOrdersRepository {
  StubPurchaseOrdersRepository();

  static final List<PurchaseOrder> _seed = <PurchaseOrder>[
    PurchaseOrder(
      id: 'po-2026-001',
      number: 'PO-2026-001',
      vendorId: 'v-001',
      vendorName: 'Acme Supplies',
      createdAt: DateTime.utc(2026, 5, 2, 10, 30),
      expectedAt: DateTime.utc(2026, 5, 16),
      status: PurchaseOrderStatus.partiallyReceived,
      totalAmount: r'$1,180.00',
      sourcePurchaseRequestId: 'pr-005',
      lineItems: const [
        PurchaseOrderLine(
          id: 'po-2026-001-li-1',
          description: 'Apple TV 4K',
          sku: 'APL-TV4K',
          orderedQuantity: 4,
          receivedQuantity: 4,
          unitPrice: r'$170.00',
          lineTotal: r'$680.00',
        ),
        PurchaseOrderLine(
          id: 'po-2026-001-li-2',
          description: 'HDMI cables (10m)',
          orderedQuantity: 10,
          receivedQuantity: 6,
          unitPrice: r'$50.00',
          lineTotal: r'$500.00',
        ),
      ],
    ),
    PurchaseOrder(
      id: 'po-2026-002',
      number: 'PO-2026-002',
      vendorId: 'v-002',
      vendorName: 'Globex Electronics',
      createdAt: DateTime.utc(2026, 4, 28, 15, 0),
      expectedAt: DateTime.utc(2026, 5, 12),
      status: PurchaseOrderStatus.fullyReceived,
      totalAmount: r'$2,550.00',
      lineItems: const [
        PurchaseOrderLine(
          id: 'po-2026-002-li-1',
          description: 'Network switch — 24 port',
          sku: 'NET-SW24',
          orderedQuantity: 3,
          receivedQuantity: 3,
          unitPrice: r'$850.00',
          lineTotal: r'$2,550.00',
        ),
      ],
    ),
    PurchaseOrder(
      id: 'po-2026-003',
      number: 'PO-2026-003',
      vendorId: 'v-003',
      vendorName: 'Initech Office',
      createdAt: DateTime.utc(2026, 5, 6, 9, 45),
      expectedAt: DateTime.utc(2026, 5, 20),
      status: PurchaseOrderStatus.open,
      totalAmount: r'$890.00',
      lineItems: const [
        PurchaseOrderLine(
          id: 'po-2026-003-li-1',
          description: 'Office stationery bundle',
          orderedQuantity: 1,
          receivedQuantity: 0,
          unitPrice: r'$890.00',
          lineTotal: r'$890.00',
        ),
      ],
    ),
  ];

  static final Map<String, List<GoodsReceipt>> _receipts = {
    'po-2026-001': [
      GoodsReceipt(
        id: 'gr-001',
        purchaseOrderId: 'po-2026-001',
        receivedAt: DateTime.utc(2026, 5, 8, 11, 0),
        receivedBy: 'Sokha Tep',
        lines: const [
          GoodsReceiptLine(
              purchaseOrderLineId: 'po-2026-001-li-1', quantity: 4),
          GoodsReceiptLine(
              purchaseOrderLineId: 'po-2026-001-li-2', quantity: 6),
        ],
        note: 'Cables short — 4 outstanding from Acme.',
      ),
    ],
    'po-2026-002': [
      GoodsReceipt(
        id: 'gr-002',
        purchaseOrderId: 'po-2026-002',
        receivedAt: DateTime.utc(2026, 5, 10, 14, 0),
        receivedBy: 'Sothea Pich',
        lines: const [
          GoodsReceiptLine(
              purchaseOrderLineId: 'po-2026-002-li-1', quantity: 3),
        ],
      ),
    ],
  };

  static int _idCounter = 100;

  @override
  Future<List<PurchaseOrder>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<PurchaseOrder>> watchAll() async* {
    yield List.unmodifiable(_seed);
  }

  @override
  Future<PurchaseOrder?> findById(String id) async {
    for (final p in _seed) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<PurchaseOrder> create(PurchaseOrder draft) async {
    _idCounter++;
    final id = 'po-2026-${_idCounter.toString().padLeft(3, '0')}';
    final persisted = draft.copyWith(
      id: id,
      number: id.toUpperCase(),
      createdAt: DateTime.now().toUtc(),
    );
    _seed.insert(0, persisted);
    return persisted;
  }

  @override
  Future<void> recordGoodsReceipt(GoodsReceipt receipt) async {
    final idx = _seed.indexWhere((p) => p.id == receipt.purchaseOrderId);
    if (idx == -1) {
      throw StateError('PO "${receipt.purchaseOrderId}" not found');
    }
    final po = _seed[idx];
    final qtyByLineId = {for (final l in receipt.lines) l.purchaseOrderLineId: l.quantity};
    final updatedLines = <PurchaseOrderLine>[];
    for (final line in po.lineItems) {
      final extra = qtyByLineId[line.id] ?? 0;
      if (extra == 0) {
        updatedLines.add(line);
        continue;
      }
      final newReceived = line.receivedQuantity + extra;
      if (newReceived > line.orderedQuantity) {
        throw StateError('Over-receipt on line "${line.id}"');
      }
      updatedLines.add(line.copyWith(receivedQuantity: newReceived));
    }
    final allFull =
        updatedLines.every((l) => l.receivedQuantity >= l.orderedQuantity);
    final anyReceived = updatedLines.any((l) => l.receivedQuantity > 0);
    final nextStatus = allFull
        ? PurchaseOrderStatus.fullyReceived
        : (anyReceived
            ? PurchaseOrderStatus.partiallyReceived
            : PurchaseOrderStatus.open);
    _seed[idx] =
        po.copyWith(lineItems: updatedLines, status: nextStatus);
    (_receipts[receipt.purchaseOrderId] ??= <GoodsReceipt>[]).add(receipt);
  }

  @override
  Future<List<GoodsReceipt>> receiptsFor(String purchaseOrderId) async {
    return List.unmodifiable(
        _receipts[purchaseOrderId] ?? const <GoodsReceipt>[]);
  }
}
