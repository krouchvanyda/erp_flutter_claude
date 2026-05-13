import '../entities/leave_request.dart';

/// Slice 7.2.2 — derive an effective balance per leave type.
///
/// **Why a derivation, not a stored field**: the seed-provided
/// `usedDays` reflects what was booked at the start of the period, but
/// new requests can land between then and now. By layering approved
/// requests on top of the baseline we keep the widget honest without
/// rewriting the seed on every approval.
///
/// Only `approved` requests are counted. `pending` / `rejected` /
/// `cancelled` leave the balance untouched — surfacing pending balance
/// would lie about what the employee can actually book today.
List<LeaveBalance> computeEffectiveBalances({
  required List<LeaveBalance> baselines,
  required List<LeaveRequest> requests,
  required String employeeId,
}) {
  final approvedByType = <LeaveType, int>{};
  for (final r in requests) {
    if (r.employeeId != employeeId) continue;
    if (r.status != LeaveRequestStatus.approved) continue;
    approvedByType.update(r.type, (v) => v + r.days, ifAbsent: () => r.days);
  }

  final out = <LeaveBalance>[];
  // Preserve the order the baselines came in so the widget renders the
  // expected leave types even when usage is zero.
  for (final b in baselines) {
    if (b.employeeId != employeeId) continue;
    final extra = approvedByType[b.type] ?? 0;
    out.add(b.copyWith(usedDays: b.usedDays + extra));
  }
  return out;
}
