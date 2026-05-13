import '../../domain/entities/vendor.dart';
import '../../domain/entities/vendor_scorecard.dart';
import '../../domain/repositories/vendors_repository.dart';

/// In-memory vendor seed (Slice 4.3.1).
class StubVendorsRepository implements VendorsRepository {
  StubVendorsRepository();

  static final List<Vendor> _seed = <Vendor>[
    Vendor(
      id: 'v-001',
      name: 'Acme Supplies',
      taxId: 'TIN-100-201',
      email: 'orders@acme-supplies.example',
      phone: '+855 23 555 0101',
      address: '12 Russian Blvd, Phnom Penh',
      status: VendorStatus.active,
      onboardedAt: DateTime.utc(2024, 11, 3),
      contactPerson: 'Nita Sok',
    ),
    Vendor(
      id: 'v-002',
      name: 'Globex Electronics',
      taxId: 'TIN-100-411',
      email: 'sales@globex-elec.example',
      phone: '+855 23 555 0233',
      address: '88 Norodom Blvd, Phnom Penh',
      status: VendorStatus.active,
      onboardedAt: DateTime.utc(2025, 2, 14),
      contactPerson: 'Pisey Chan',
    ),
    Vendor(
      id: 'v-003',
      name: 'Initech Office',
      taxId: 'TIN-100-722',
      email: 'support@initech-off.example',
      phone: '+855 12 555 0399',
      address: '7 Sothearos Blvd, Phnom Penh',
      status: VendorStatus.onHold,
      onboardedAt: DateTime.utc(2025, 6, 1),
      notes: 'Late delivery on PO-2026-003 — under review.',
    ),
    Vendor(
      id: 'v-004',
      name: 'Wonka Industries',
      taxId: 'TIN-100-848',
      email: 'ar@wonka-ind.example',
      phone: '+855 78 555 0444',
      address: '102 Monivong Blvd, Phnom Penh',
      status: VendorStatus.archived,
      onboardedAt: DateTime.utc(2023, 1, 10),
      notes: 'Contract expired 2025-12-31, not renewed.',
    ),
  ];

  static final Map<String, VendorPerformanceStats> _stats = {
    'v-001': const VendorPerformanceStats(
      totalDeliveries: 28,
      onTimeDeliveries: 26,
      totalUnitsReceived: 412,
      defectiveUnits: 6,
      totalSpend: r'$48,200.00',
      openDisputes: 0,
    ),
    'v-002': const VendorPerformanceStats(
      totalDeliveries: 14,
      onTimeDeliveries: 13,
      totalUnitsReceived: 64,
      defectiveUnits: 1,
      totalSpend: r'$31,750.00',
      openDisputes: 0,
    ),
    'v-003': const VendorPerformanceStats(
      totalDeliveries: 11,
      onTimeDeliveries: 7,
      totalUnitsReceived: 220,
      defectiveUnits: 14,
      totalSpend: r'$8,900.00',
      openDisputes: 2,
    ),
    'v-004': const VendorPerformanceStats(
      totalDeliveries: 64,
      onTimeDeliveries: 60,
      totalUnitsReceived: 1280,
      defectiveUnits: 32,
      totalSpend: r'$112,400.00',
      openDisputes: 0,
    ),
  };

  static int _idCounter = 100;

  @override
  Future<List<Vendor>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<Vendor>> watchAll() async* {
    yield List.unmodifiable(_seed);
  }

  @override
  Future<Vendor?> findById(String id) async {
    for (final v in _seed) {
      if (v.id == id) return v;
    }
    return null;
  }

  @override
  Future<Vendor> create(Vendor draft) async {
    _idCounter++;
    final id = 'v-${_idCounter.toString().padLeft(3, '0')}';
    final persisted = draft.copyWith(
      id: id,
      onboardedAt: DateTime.now().toUtc(),
    );
    _seed.insert(0, persisted);
    return persisted;
  }

  @override
  Future<VendorPerformanceStats> performanceStatsFor(String vendorId) async {
    return _stats[vendorId] ??
        const VendorPerformanceStats(
          totalDeliveries: 0,
          onTimeDeliveries: 0,
          totalUnitsReceived: 0,
          defectiveUnits: 0,
          totalSpend: r'$0.00',
          openDisputes: 0,
        );
  }
}
