import '../entities/timesheet_entry.dart';

abstract class TimesheetsRepository {
  Future<List<TimesheetEntry>> getAll();
  Stream<List<TimesheetEntry>> watchAll();

  Future<List<TimesheetEntry>> getForEmployee(String employeeId);
  Stream<List<TimesheetEntry>> watchForEmployee(String employeeId);

  Future<TimesheetEntry?> findById(String id);

  /// Slice 8.2.1 — repo assigns the id when blank.
  Future<TimesheetEntry> create(TimesheetEntry entry);

  /// Slice 8.2.2 — caller must have already validated state via the use
  /// cases ([`submitTimesheet`] / [`approveTimesheet`] /
  /// [`rejectTimesheet`]).
  Future<TimesheetEntry> update(TimesheetEntry entry);
}
