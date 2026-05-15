import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/hr/domain/entities/leave_request.dart';
import 'package:erp_mobile/features/hr/domain/usecases/decide_leave_request.dart';
import 'package:test/test.dart';

LeaveRequest _pending() => LeaveRequest(
      id: 'lv-1',
      employeeId: 'emp-1',
      employeeName: 'A',
      type: LeaveType.annual,
      fromDate: DateTime.utc(2026, 5, 16),
      toDate: DateTime.utc(2026, 5, 17),
      reason: 'r',
      status: LeaveRequestStatus.pending,
      requestedAt: DateTime.utc(2026, 5, 14),
    );

void main() {
  group('approveLeaveRequest', () {
    test('stamps approver + actionedAt and flips to approved', () {
      final r = approveLeaveRequest(
        request: _pending(),
        approverId: 'mgr-1',
        now: DateTime.utc(2026, 5, 15, 10),
      );
      expect(r.status, LeaveRequestStatus.approved);
      expect(r.approvedBy, 'mgr-1');
      expect(r.actionedAt, DateTime.utc(2026, 5, 15, 10));
    });

    test('throws ConflictFailure if already approved', () {
      final already = _pending().copyWith(status: LeaveRequestStatus.approved);
      expect(
        () => approveLeaveRequest(
          request: already,
          approverId: 'mgr-1',
          now: DateTime.utc(2026, 5, 15),
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });

  group('rejectLeaveRequest', () {
    test('records the reason verbatim (trimmed)', () {
      final r = rejectLeaveRequest(
        request: _pending(),
        approverId: 'mgr-1',
        now: DateTime.utc(2026, 5, 15),
        reason: '  No coverage  ',
      );
      expect(r.status, LeaveRequestStatus.rejected);
      expect(r.decisionNote, 'No coverage');
    });

    test('throws ValidationFailure when reason is empty', () {
      expect(
        () => rejectLeaveRequest(
          request: _pending(),
          approverId: 'mgr-1',
          now: DateTime.utc(2026, 5, 15),
          reason: '   ',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('throws ConflictFailure when not pending', () {
      final already = _pending().copyWith(status: LeaveRequestStatus.rejected);
      expect(
        () => rejectLeaveRequest(
          request: already,
          approverId: 'mgr-1',
          now: DateTime.utc(2026, 5, 15),
          reason: 'r',
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });

  group('cancelLeaveRequest', () {
    test('flips to cancelled', () {
      final r = cancelLeaveRequest(
        request: _pending(),
        now: DateTime.utc(2026, 5, 15),
      );
      expect(r.status, LeaveRequestStatus.cancelled);
    });

    test('throws ConflictFailure once decided', () {
      final approved =
          _pending().copyWith(status: LeaveRequestStatus.approved);
      expect(
        () => cancelLeaveRequest(
          request: approved,
          now: DateTime.utc(2026, 5, 15),
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });
}
