import '../entities/trial_balance_row.dart';

/// Domain contract for the trial balance report (Slice 3.3.2).
///
/// Returns the full report — pagination is a presentation concern
/// handled by [`paginate`]. Future date-range filtering would land
/// as a method parameter here.
abstract class TrialBalanceRepository {
  Future<List<TrialBalanceRow>> getReport();
}
