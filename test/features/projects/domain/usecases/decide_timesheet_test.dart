import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/projects/domain/entities/timesheet_entry.dart';
import 'package:erp_mobile/features/projects/domain/usecases/decide_timesheet.dart';
import 'package:test/test.dart';

TimesheetEntry _submitted() => TimesheetEntry(
      id: 'ts',
      employeeId: 'emp-1',
      employeeName: 'A',
      projectId: 'p',
      projectName: 'P',
      date: DateTime.utc(2026, 5, 14),
      hours: 4,
      description: 'r',
      status: TimesheetStatus.submitted,
    );

void main() {
  group('approveTimesheetEntry', () {
    test('stamps approver and flips to approved', () {
      final r = approveTimesheetEntry(
        entry: _submitted(),
        approverId: 'mgr-1',
        now: DateTime.utc(2026, 5, 15, 9),
      );
      expect(r.status, TimesheetStatus.approved);
      expect(r.approverId, 'mgr-1');
      expect(r.actionedAt, DateTime.utc(2026, 5, 15, 9));
    });

    test('throws when not submitted', () {
      final draft = _submitted().copyWith(status: TimesheetStatus.draft);
      expect(
        () => approveTimesheetEntry(
          entry: draft,
          approverId: 'mgr-1',
          now: DateTime.utc(2026, 5, 15),
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });

  group('rejectTimesheetEntry', () {
    test('records reason verbatim (trimmed)', () {
      final r = rejectTimesheetEntry(
        entry: _submitted(),
        approverId: 'mgr-1',
        now: DateTime.utc(2026, 5, 15),
        reason: '  Wrong project  ',
      );
      expect(r.status, TimesheetStatus.rejected);
      expect(r.decisionNote, 'Wrong project');
    });

    test('throws ValidationFailure when reason is empty', () {
      expect(
        () => rejectTimesheetEntry(
          entry: _submitted(),
          approverId: 'mgr-1',
          now: DateTime.utc(2026, 5, 15),
          reason: '   ',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('throws ConflictFailure when not submitted', () {
      final approved =
          _submitted().copyWith(status: TimesheetStatus.approved);
      expect(
        () => rejectTimesheetEntry(
          entry: approved,
          approverId: 'mgr-1',
          now: DateTime.utc(2026, 5, 15),
          reason: 'r',
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });

  group('reopenRejectedTimesheet', () {
    test('rejected → draft (clears decision metadata)', () {
      final rejected = _submitted().copyWith(
        status: TimesheetStatus.rejected,
        approverId: 'mgr-1',
        actionedAt: DateTime.utc(2026, 5, 15),
        decisionNote: 'r',
      );
      final r = reopenRejectedTimesheet(rejected);
      expect(r.status, TimesheetStatus.draft);
      expect(r.approverId, isNull);
      expect(r.actionedAt, isNull);
      expect(r.decisionNote, isNull);
    });

    test('throws when not rejected', () {
      expect(
        () => reopenRejectedTimesheet(_submitted()),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });
}
