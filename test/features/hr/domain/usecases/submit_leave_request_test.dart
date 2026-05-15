import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/hr/domain/entities/leave_request.dart';
import 'package:erp_mobile/features/hr/domain/usecases/submit_leave_request.dart';
import 'package:test/test.dart';

void main() {
  group('validateLeaveRequest', () {
    final now = DateTime.utc(2026, 5, 15);

    test('accepts a well-formed request', () {
      final r = validateLeaveRequest(
        employeeId: 'emp-001',
        employeeName: 'Alice',
        type: LeaveType.annual,
        fromDate: DateTime.utc(2026, 5, 16),
        toDate: DateTime.utc(2026, 5, 20),
        reason: 'Family wedding',
        now: now,
      );
      expect(r.status, LeaveRequestStatus.pending);
      expect(r.id, isEmpty); // assigned by repo
      expect(r.days, 5);
      expect(r.reason, 'Family wedding');
    });

    test('strips time of day from from/to', () {
      final r = validateLeaveRequest(
        employeeId: 'emp-001',
        employeeName: 'Alice',
        type: LeaveType.sick,
        fromDate: DateTime.utc(2026, 5, 16, 10, 30),
        toDate: DateTime.utc(2026, 5, 16, 14, 0),
        reason: 'cold',
        now: now,
      );
      expect(r.fromDate, DateTime.utc(2026, 5, 16));
      expect(r.toDate, DateTime.utc(2026, 5, 16));
      expect(r.days, 1);
    });

    test('rejects past start date', () {
      expect(
        () => validateLeaveRequest(
          employeeId: 'emp-001',
          employeeName: 'Alice',
          type: LeaveType.annual,
          fromDate: DateTime.utc(2026, 5, 14),
          toDate: DateTime.utc(2026, 5, 16),
          reason: 'r',
          now: now,
        ),
        throwsA(isA<ValidationFailure>().having(
          (f) => f.fieldErrors,
          'fieldErrors',
          containsPair('fromDate', isNotEmpty),
        )),
      );
    });

    test('rejects to-before-from', () {
      expect(
        () => validateLeaveRequest(
          employeeId: 'emp-001',
          employeeName: 'Alice',
          type: LeaveType.annual,
          fromDate: DateTime.utc(2026, 5, 20),
          toDate: DateTime.utc(2026, 5, 18),
          reason: 'r',
          now: now,
        ),
        throwsA(isA<ValidationFailure>().having(
          (f) => f.fieldErrors,
          'fieldErrors',
          containsPair('toDate', isNotEmpty),
        )),
      );
    });

    test('rejects empty employee id and reason', () {
      expect(
        () => validateLeaveRequest(
          employeeId: '',
          employeeName: 'Alice',
          type: LeaveType.annual,
          fromDate: DateTime.utc(2026, 5, 16),
          toDate: DateTime.utc(2026, 5, 17),
          reason: '   ',
          now: now,
        ),
        throwsA(isA<ValidationFailure>().having(
          (f) => f.fieldErrors,
          'fieldErrors',
          allOf(
            containsPair('employeeId', isNotEmpty),
            containsPair('reason', isNotEmpty),
          ),
        )),
      );
    });
  });
}
