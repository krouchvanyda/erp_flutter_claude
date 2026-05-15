import '../../../../core/error/failure.dart';
import '../entities/timesheet_entry.dart';

/// Slice 8.2.2 — manager actions over a submitted timesheet entry.
///
/// State-machine guard: both throw [ConflictFailure] when the entry is
/// not currently `submitted`. Mirrors the leave-request decide use
/// cases for shape consistency.
TimesheetEntry approveTimesheetEntry({
  required TimesheetEntry entry,
  required String approverId,
  required DateTime now,
  String? note,
}) {
  if (entry.status != TimesheetStatus.submitted) {
    throw ConflictFailure(message: 'Already ${entry.status.name}');
  }
  return entry.copyWith(
    status: TimesheetStatus.approved,
    approverId: approverId,
    actionedAt: now,
    decisionNote: note,
  );
}

TimesheetEntry rejectTimesheetEntry({
  required TimesheetEntry entry,
  required String approverId,
  required DateTime now,
  required String reason,
}) {
  if (entry.status != TimesheetStatus.submitted) {
    throw ConflictFailure(message: 'Already ${entry.status.name}');
  }
  if (reason.trim().isEmpty) {
    throw ValidationFailure(fieldErrors: {
      'reason': ['Required'],
    });
  }
  return entry.copyWith(
    status: TimesheetStatus.rejected,
    approverId: approverId,
    actionedAt: now,
    decisionNote: reason.trim(),
  );
}

/// Employee re-edits a rejected entry → drops back to draft so the
/// form unlocks. Approved entries cannot be re-opened from this path
/// (would require an admin reversal — not in the demo scope).
///
/// **Why we construct directly**: `copyWith` collapses nulls to "no
/// change" via `??`, so passing `approverId: null` would silently
/// preserve the rejecter's id. Building a fresh instance is the
/// readable way to clear those fields.
TimesheetEntry reopenRejectedTimesheet(TimesheetEntry entry) {
  if (entry.status != TimesheetStatus.rejected) {
    throw ConflictFailure(message: 'Only rejected entries can be reopened');
  }
  return TimesheetEntry(
    id: entry.id,
    employeeId: entry.employeeId,
    employeeName: entry.employeeName,
    projectId: entry.projectId,
    projectName: entry.projectName,
    date: entry.date,
    hours: entry.hours,
    description: entry.description,
    status: TimesheetStatus.draft,
    taskId: entry.taskId,
    taskTitle: entry.taskTitle,
  );
}
