import '../entities/vendor.dart';
import '../entities/vendor_scorecard.dart';

abstract class VendorsRepository {
  Future<List<Vendor>> getAll();
  Stream<List<Vendor>> watchAll();
  Future<Vendor?> findById(String id);

  /// Persists a new vendor (Slice 4.3.2 onboarding form). The repo
  /// assigns the id; returns the persisted record.
  Future<Vendor> create(Vendor draft);

  /// Returns raw performance stats for [vendorId] (Slice 4.3.3). The
  /// scorecard math lives in `computeVendorScorecard` so the repo
  /// stays a dumb data source.
  Future<VendorPerformanceStats> performanceStatsFor(String vendorId);
}
