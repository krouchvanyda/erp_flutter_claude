import '../entities/attendance_entry.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceEntry>> getForEmployee(String employeeId);
  Stream<List<AttendanceEntry>> watchForEmployee(String employeeId);

  /// Latest entry for [employeeId] regardless of date. Used by the
  /// clock-in/out button to decide which action is legal next.
  Future<AttendanceEntry?> latestFor(String employeeId);

  Future<AttendanceEntry> create(AttendanceEntry entry);
  Future<AttendanceEntry> update(AttendanceEntry entry);
}
