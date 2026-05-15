import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/projects/domain/entities/timesheet_entry.dart';
import 'package:erp_mobile/features/projects/domain/usecases/submit_timesheet.dart';
import 'package:test/test.dart';

void main() {
  group('validateTimesheetEntry', () {
    final now = DateTime.utc(2026, 5, 15);

    test('accepts a well-formed entry as draft', () {
      final r = validateTimesheetEntry(
        employeeId: 'emp-1',
        employeeName: 'Alice',
        projectId: 'proj-1',
        projectName: 'Alpha',
        date: DateTime.utc(2026, 5, 14),
        hours: 6.5,
        description: 'pair programming',
        now: now,
      );
      expect(r.status, TimesheetStatus.draft);
      expect(r.id, isEmpty);
      expect(r.hours, 6.5);
    });

    test('rejects future date', () {
      expect(
        () => validateTimesheetEntry(
          employeeId: 'emp-1',
          employeeName: 'Alice',
          projectId: 'proj-1',
          projectName: 'Alpha',
          date: DateTime.utc(2026, 5, 16), // tomorrow
          hours: 4,
          description: 'r',
          now: now,
        ),
        throwsA(isA<ValidationFailure>().having(
          (f) => f.fieldErrors,
          'fieldErrors',
          containsPair('date', isNotEmpty),
        )),
      );
    });

    test('rejects zero or negative hours', () {
      expect(
        () => validateTimesheetEntry(
          employeeId: 'emp-1',
          employeeName: 'Alice',
          projectId: 'proj-1',
          projectName: 'Alpha',
          date: DateTime.utc(2026, 5, 14),
          hours: 0,
          description: 'r',
          now: now,
        ),
        throwsA(isA<ValidationFailure>().having(
          (f) => f.fieldErrors,
          'fieldErrors',
          containsPair('hours', isNotEmpty),
        )),
      );
    });

    test('caps hours at 24 in a single line', () {
      expect(
        () => validateTimesheetEntry(
          employeeId: 'emp-1',
          employeeName: 'Alice',
          projectId: 'proj-1',
          projectName: 'Alpha',
          date: DateTime.utc(2026, 5, 14),
          hours: 25,
          description: 'r',
          now: now,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('requires description and project', () {
      expect(
        () => validateTimesheetEntry(
          employeeId: 'emp-1',
          employeeName: 'Alice',
          projectId: '',
          projectName: '',
          date: DateTime.utc(2026, 5, 14),
          hours: 4,
          description: '   ',
          now: now,
        ),
        throwsA(isA<ValidationFailure>().having(
          (f) => f.fieldErrors,
          'fieldErrors',
          allOf(
            containsPair('projectId', isNotEmpty),
            containsPair('description', isNotEmpty),
          ),
        )),
      );
    });
  });

  group('submitTimesheetEntry', () {
    test('promotes draft to submitted', () {
      final draft = TimesheetEntry(
        id: 'ts',
        employeeId: 'emp-1',
        employeeName: 'A',
        projectId: 'p',
        projectName: 'P',
        date: DateTime.utc(2026, 5, 14),
        hours: 4,
        description: 'r',
        status: TimesheetStatus.draft,
      );
      expect(submitTimesheetEntry(draft).status, TimesheetStatus.submitted);
    });

    test('throws when not draft', () {
      final approved = TimesheetEntry(
        id: 'ts',
        employeeId: 'emp-1',
        employeeName: 'A',
        projectId: 'p',
        projectName: 'P',
        date: DateTime.utc(2026, 5, 14),
        hours: 4,
        description: 'r',
        status: TimesheetStatus.approved,
      );
      expect(
        () => submitTimesheetEntry(approved),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });
}
