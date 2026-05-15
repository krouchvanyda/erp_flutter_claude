import 'package:erp_mobile/features/projects/domain/entities/timesheet_entry.dart';
import 'package:erp_mobile/features/projects/domain/usecases/compute_utilization.dart';
import 'package:test/test.dart';

TimesheetEntry _e({
  String employeeId = 'emp-1',
  String name = 'Alice',
  required DateTime date,
  required num hours,
  TimesheetStatus status = TimesheetStatus.approved,
}) =>
    TimesheetEntry(
      id: 'e-${date.day}-$employeeId',
      employeeId: employeeId,
      employeeName: name,
      projectId: 'p',
      projectName: 'P',
      date: date,
      hours: hours,
      description: 'r',
      status: status,
    );

void main() {
  group('computeUtilization', () {
    test('sums approved hours per employee', () {
      final out = computeUtilization(
        entries: [
          _e(date: DateTime.utc(2026, 5, 11), hours: 4),
          _e(date: DateTime.utc(2026, 5, 12), hours: 4),
          _e(date: DateTime.utc(2026, 5, 13), hours: 6,
              employeeId: 'emp-2', name: 'Bob'),
        ],
        from: DateTime.utc(2026, 5, 11),
        to: DateTime.utc(2026, 5, 15),
      );
      final byId = {for (final b in out) b.employeeId: b};
      expect(byId['emp-1']!.loggedHours, 8);
      expect(byId['emp-2']!.loggedHours, 6);
    });

    test('non-approved entries excluded by default', () {
      final out = computeUtilization(
        entries: [
          _e(date: DateTime.utc(2026, 5, 11), hours: 4),
          _e(
              date: DateTime.utc(2026, 5, 12),
              hours: 100,
              status: TimesheetStatus.draft),
          _e(
              date: DateTime.utc(2026, 5, 13),
              hours: 100,
              status: TimesheetStatus.submitted),
        ],
        from: DateTime.utc(2026, 5, 11),
        to: DateTime.utc(2026, 5, 15),
      );
      expect(out.single.loggedHours, 4);
    });

    test('entries outside window are skipped', () {
      final out = computeUtilization(
        entries: [
          _e(date: DateTime.utc(2026, 5, 1), hours: 8),
          _e(date: DateTime.utc(2026, 5, 11), hours: 4),
        ],
        from: DateTime.utc(2026, 5, 11),
        to: DateTime.utc(2026, 5, 15),
      );
      expect(out.single.loggedHours, 4);
    });

    test('target is weekday-count × 8 by default', () {
      // 2026-05-11 (Mon) → 2026-05-15 (Fri) = 5 weekdays = 40h target.
      final out = computeUtilization(
        entries: [_e(date: DateTime.utc(2026, 5, 11), hours: 4)],
        from: DateTime.utc(2026, 5, 11),
        to: DateTime.utc(2026, 5, 15),
      );
      expect(out.single.targetHours, 40);
      expect(out.single.utilizationPct, 10);
    });

    test('utilizationPct is 0 when target is 0 (no NaN)', () {
      // Window is Sat–Sun only → 0 weekdays → target=0.
      final out = computeUtilization(
        entries: [
          _e(date: DateTime.utc(2026, 5, 16), hours: 4), // Saturday
        ],
        from: DateTime.utc(2026, 5, 16),
        to: DateTime.utc(2026, 5, 17),
      );
      expect(out.single.utilizationPct, 0);
    });

    test('sorts by utilizationPct descending', () {
      final out = computeUtilization(
        entries: [
          _e(date: DateTime.utc(2026, 5, 11), hours: 2),
          _e(
              date: DateTime.utc(2026, 5, 11),
              hours: 8,
              employeeId: 'emp-2',
              name: 'Bob'),
        ],
        from: DateTime.utc(2026, 5, 11),
        to: DateTime.utc(2026, 5, 15),
      );
      expect(out.first.employeeId, 'emp-2');
      expect(out.last.employeeId, 'emp-1');
    });

    test('inverted window returns empty', () {
      expect(
        computeUtilization(
          entries: [_e(date: DateTime.utc(2026, 5, 11), hours: 4)],
          from: DateTime.utc(2026, 5, 15),
          to: DateTime.utc(2026, 5, 11),
        ),
        isEmpty,
      );
    });
  });

  group('countWeekdays', () {
    test('Mon–Fri returns 5', () {
      expect(
        countWeekdays(DateTime.utc(2026, 5, 11), DateTime.utc(2026, 5, 15)),
        5,
      );
    });

    test('Mon–Sun returns 5', () {
      expect(
        countWeekdays(DateTime.utc(2026, 5, 11), DateTime.utc(2026, 5, 17)),
        5,
      );
    });

    test('Sat–Sun returns 0', () {
      expect(
        countWeekdays(DateTime.utc(2026, 5, 16), DateTime.utc(2026, 5, 17)),
        0,
      );
    });
  });
}
