import 'dart:async';

import '../../domain/entities/purchase_request.dart';
import '../../domain/repositories/purchase_requests_repository.dart';

/// In-memory PR seed (Slice 4.1.1). Mirrors the `StubInvoicesRepository`
/// pattern so swapping in a drift-backed impl later is mechanical.
class StubPurchaseRequestsRepository implements PurchaseRequestsRepository {
  StubPurchaseRequestsRepository();

  static final List<PurchaseRequest> _seed = <PurchaseRequest>[
    PurchaseRequest(
      id: 'pr-001',
      number: 'PR-2026-001',
      requesterName: 'Sokha Tep',
      costCenter: 'CC-ENG-101',
      approverName: 'Vibol Chea',
      createdAt: DateTime.utc(2026, 5, 11, 9, 15),
      status: PurchaseRequestStatus.submitted,
      totalAmount: r'$2,450.00',
      lineItems: const [
        PurchaseRequestLine(
          id: 'pr-001-li-1',
          description: 'Dell P2422H 24" monitor',
          sku: 'DELL-P2422H',
          quantity: 5,
          unitPrice: r'$320.00',
          lineTotal: r'$1,600.00',
        ),
        PurchaseRequestLine(
          id: 'pr-001-li-2',
          description: 'Logitech MX Master 3S',
          sku: 'LOG-MX3S',
          quantity: 5,
          unitPrice: r'$170.00',
          lineTotal: r'$850.00',
        ),
      ],
      justification: 'Onboarding kit for the new platform team hires.',
    ),
    PurchaseRequest(
      id: 'pr-002',
      number: 'PR-2026-002',
      requesterName: 'Sothea Pich',
      costCenter: 'CC-OPS-204',
      approverName: 'Vibol Chea',
      createdAt: DateTime.utc(2026, 5, 9, 14, 5),
      status: PurchaseRequestStatus.approved,
      totalAmount: r'$890.00',
      lineItems: const [
        PurchaseRequestLine(
          id: 'pr-002-li-1',
          description: 'Office supplies (paper, pens, folders)',
          quantity: 1,
          unitPrice: r'$890.00',
          lineTotal: r'$890.00',
        ),
      ],
      justification: 'Quarterly stationery refill.',
    ),
    PurchaseRequest(
      id: 'pr-003',
      number: 'PR-2026-003',
      requesterName: 'Dara Nuon',
      costCenter: 'CC-MKT-305',
      approverName: 'Bopha Lim',
      createdAt: DateTime.utc(2026, 5, 7, 10, 40),
      status: PurchaseRequestStatus.draft,
      totalAmount: r'$5,200.00',
      lineItems: const [
        PurchaseRequestLine(
          id: 'pr-003-li-1',
          description: 'Trade show booth rental — Q3',
          quantity: 1,
          unitPrice: r'$5,200.00',
          lineTotal: r'$5,200.00',
        ),
      ],
    ),
    PurchaseRequest(
      id: 'pr-004',
      number: 'PR-2026-004',
      requesterName: 'Mara Sok',
      costCenter: 'CC-ENG-101',
      approverName: 'Vibol Chea',
      createdAt: DateTime.utc(2026, 5, 4, 11, 20),
      status: PurchaseRequestStatus.rejected,
      totalAmount: r'$12,800.00',
      lineItems: const [
        PurchaseRequestLine(
          id: 'pr-004-li-1',
          description: 'M2 Mac Studio (overspec for role)',
          sku: 'MAC-STD-M2',
          quantity: 4,
          unitPrice: r'$3,200.00',
          lineTotal: r'$12,800.00',
        ),
      ],
      justification: 'Workstation refresh.',
    ),
    PurchaseRequest(
      id: 'pr-005',
      number: 'PR-2026-005',
      requesterName: 'Sokha Tep',
      costCenter: 'CC-ENG-101',
      approverName: 'Vibol Chea',
      createdAt: DateTime.utc(2026, 5, 1, 16, 0),
      status: PurchaseRequestStatus.converted,
      totalAmount: r'$1,180.00',
      lineItems: const [
        PurchaseRequestLine(
          id: 'pr-005-li-1',
          description: 'Apple TV 4K (conference rooms)',
          sku: 'APL-TV4K',
          quantity: 4,
          unitPrice: r'$170.00',
          lineTotal: r'$680.00',
        ),
        PurchaseRequestLine(
          id: 'pr-005-li-2',
          description: 'HDMI cables (10m)',
          quantity: 10,
          unitPrice: r'$50.00',
          lineTotal: r'$500.00',
        ),
      ],
    ),
  ];

  static int _idCounter = 100;

  // Broadcast channel so `watchAll` subscribers re-receive after any
  // mutation. Without this the bloc only sees the initial yield and a
  // newly-created PR never shows up in the list.
  static final StreamController<List<PurchaseRequest>> _changes =
      StreamController<List<PurchaseRequest>>.broadcast();

  static void _emit() => _changes.add(List.unmodifiable(_seed));

  @override
  Future<List<PurchaseRequest>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<PurchaseRequest>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<PurchaseRequest?> findById(String id) async {
    for (final p in _seed) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<void> setStatus(
    String id,
    PurchaseRequestStatus newStatus,
  ) async {
    final idx = _seed.indexWhere((p) => p.id == id);
    if (idx == -1) throw StateError('Purchase request "$id" not found');
    _seed[idx] = _seed[idx].copyWith(status: newStatus);
    _emit();
  }

  @override
  Future<PurchaseRequest> create(PurchaseRequest draft) async {
    _idCounter++;
    final id = 'pr-$_idCounter';
    final number = 'PR-2026-${_idCounter.toString().padLeft(3, '0')}';
    final persisted = draft.copyWith(
      id: id,
      number: number,
      createdAt: DateTime.now().toUtc(),
    );
    _seed.insert(0, persisted);
    _emit();
    return persisted;
  }
}
