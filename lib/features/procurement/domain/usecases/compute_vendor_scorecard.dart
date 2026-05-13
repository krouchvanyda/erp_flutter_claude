import '../entities/vendor_scorecard.dart';

/// Pure scorecard math (Slice 4.3.3).
///
/// **Composite weights**: 60% on-time, 40% defect-free, then a flat
/// -10 per open dispute, capped at -20. The exact weights matter less
/// than the fact that they live in one tested place — buyers and ops
/// will iterate on these numbers without us touching widget code.
///
/// **Edge cases** (zero deliveries, zero units): treat the missing
/// data as "no signal" → 0.0%, not "perfect". A brand-new vendor with
/// no shipments yet shouldn't read as A-grade.
VendorScorecard computeVendorScorecard(VendorPerformanceStats stats) {
  final onTime = stats.totalDeliveries == 0
      ? 0.0
      : (stats.onTimeDeliveries / stats.totalDeliveries) * 100.0;
  final defect = stats.totalUnitsReceived == 0
      ? 0.0
      : (stats.defectiveUnits / stats.totalUnitsReceived) * 100.0;
  final defectFree = (100.0 - defect).clamp(0.0, 100.0);

  final base = (onTime * 0.6) + (defectFree * 0.4);
  final disputePenalty = (stats.openDisputes * 10).clamp(0, 20);
  final composite = (base - disputePenalty).clamp(0.0, 100.0);

  final grade = switch (composite) {
    >= 90.0 => VendorGrade.a,
    >= 75.0 => VendorGrade.b,
    >= 60.0 => VendorGrade.c,
    _ => VendorGrade.d,
  };

  return VendorScorecard(
    onTimeRatePct: onTime,
    defectRatePct: defect,
    compositeScore: composite,
    grade: grade,
    totalSpend: stats.totalSpend,
    openDisputes: stats.openDisputes,
  );
}
