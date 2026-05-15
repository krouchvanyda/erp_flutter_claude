import 'package:erp_mobile/features/hr/domain/entities/leave_request.dart';
import 'package:erp_mobile/features/hr/domain/usecases/compute_leave_balance.dart';
import 'package:test/test.dart';

LeaveBalance _b(LeaveType t, {int total = 14, int used = 0}) =>
    LeaveBalance(
      employeeId: 'emp-1',
      type: t,
      totalDays: total,
      usedDays: used,
    );

LeaveRequest _req({
  String employeeId = 'emp-1',
  LeaveType type = LeaveType.annual,
  required DateTime from,
  required DateTime to,
  LeaveRequestStatus status = LeaveRequestStatus.approved,
}) =>
    LeaveRequest(
      id: 'r-${from.day}',
      employeeId: employeeId,
      employeeName: 'A',
      type: type,
      fromDate: from,
      toDate: to,
      reason: 'r',
      status: status,
      requestedAt: from,
    );

void main() {
  group('computeEffectiveBalances', () {
    test('approved requests deduct from baseline', () {
      final out = computeEffectiveBalances(
        baselines: [_b(LeaveType.annual, total: 14, used: 2)],
        requests: [
          _req(
            from: DateTime.utc(2026, 5, 16),
            to: DateTime.utc(2026, 5, 18),
          ), // 3 days
        ],
        employeeId: 'emp-1',
      );
      expect(out.single.usedDays, 5);
      expect(out.single.remainingDays, 9);
    });

    test('pending / rejected / cancelled requests do NOT deduct', () {
      final out = computeEffectiveBalances(
        baselines: [_b(LeaveType.annual, total: 10, used: 0)],
        requests: [
          _req(
            from: DateTime.utc(2026, 5, 16),
            to: DateTime.utc(2026, 5, 17),
            status: LeaveRequestStatus.pending,
          ),
          _req(
            from: DateTime.utc(2026, 5, 18),
            to: DateTime.utc(2026, 5, 19),
            status: LeaveRequestStatus.rejected,
          ),
          _req(
            from: DateTime.utc(2026, 5, 20),
            to: DateTime.utc(2026, 5, 20),
            status: LeaveRequestStatus.cancelled,
          ),
        ],
        employeeId: 'emp-1',
      );
      expect(out.single.usedDays, 0);
    });

    test('different leave types are bucketed independently', () {
      final out = computeEffectiveBalances(
        baselines: [
          _b(LeaveType.annual, total: 14, used: 0),
          _b(LeaveType.sick, total: 10, used: 0),
        ],
        requests: [
          _req(
            from: DateTime.utc(2026, 5, 16),
            to: DateTime.utc(2026, 5, 16),
            type: LeaveType.sick,
          ),
        ],
        employeeId: 'emp-1',
      );
      final byType = {for (final b in out) b.type: b};
      expect(byType[LeaveType.annual]!.usedDays, 0);
      expect(byType[LeaveType.sick]!.usedDays, 1);
    });

    test('other employees are ignored', () {
      final out = computeEffectiveBalances(
        baselines: [_b(LeaveType.annual)],
        requests: [
          _req(
            employeeId: 'emp-2',
            from: DateTime.utc(2026, 5, 16),
            to: DateTime.utc(2026, 5, 18),
          ),
        ],
        employeeId: 'emp-1',
      );
      expect(out.single.usedDays, 0);
    });

    test('remainingDays clamps at 0 when over-used', () {
      final out = computeEffectiveBalances(
        baselines: [_b(LeaveType.annual, total: 3, used: 0)],
        requests: [
          _req(
            from: DateTime.utc(2026, 5, 16),
            to: DateTime.utc(2026, 5, 25),
          ), // 10 days
        ],
        employeeId: 'emp-1',
      );
      expect(out.single.remainingDays, 0);
    });
  });
}
