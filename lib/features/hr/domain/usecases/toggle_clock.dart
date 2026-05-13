import '../../../../core/error/failure.dart';
import '../entities/attendance_entry.dart';

/// Slice 7.3.1 — sum-type result of a clock-in/out tap.
///
/// The bloc invokes [resolveClockAction] with the most recent entry +
/// "now" and gets back exactly one of:
/// - [ClockInAction] — open a new entry (replaces any older closed one
///   for the same date when there is no open one).
/// - [ClockOutAction] — close the existing open entry.
sealed class ClockAction {
  const ClockAction();
}

class ClockInAction extends ClockAction {
  const ClockInAction(this.draft);
  final AttendanceEntry draft;
}

class ClockOutAction extends ClockAction {
  const ClockOutAction(this.updated);
  final AttendanceEntry updated;
}

ClockAction resolveClockAction({
  required AttendanceEntry? latest,
  required String employeeId,
  required DateTime now,
  required String Function() newId,
  String? note,
}) {
  if (latest == null || !latest.isOpen) {
    // Fresh clock-in.
    final date = DateTime.utc(now.year, now.month, now.day);
    return ClockInAction(AttendanceEntry(
      id: newId(),
      employeeId: employeeId,
      date: date,
      clockIn: now,
      note: note,
    ));
  }
  // Defensive: server shouldn't return an open entry for a different
  // employee, but bail rather than corrupt their data.
  if (latest.employeeId != employeeId) {
    throw ConflictFailure(message: 'Open entry belongs to another employee');
  }
  if (now.isBefore(latest.clockIn)) {
    throw ValidationFailure(fieldErrors: {
      'clockOut': ['Cannot clock out before clock-in time'],
    });
  }
  return ClockOutAction(latest.copyWith(clockOut: now, note: note));
}
