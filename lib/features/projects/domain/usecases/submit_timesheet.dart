import '../../../../core/error/failure.dart';
import '../entities/timesheet_entry.dart';

/// Slice 8.2.1 — validates a draft timesheet entry before it lands in
/// the queue. Pure-Dart so the form bloc + the API receiver can both
/// reuse it.
TimesheetEntry validateTimesheetEntry({
  required String employeeId,
  required String employeeName,
  required String projectId,
  required String projectName,
  required DateTime date,
  required num hours,
  required String description,
  required DateTime now,
  String? taskId,
  String? taskTitle,
}) {
  final errors = <String, List<String>>{};
  if (employeeId.isEmpty) {
    errors.putIfAbsent('employeeId', () => []).add('Required');
  }
  if (projectId.isEmpty) {
    errors.putIfAbsent('projectId', () => []).add('Required');
  }
  if (hours <= 0) {
    errors.putIfAbsent('hours', () => []).add('Must be greater than 0');
  }
  // Cap a single line at one calendar day; the rest gets entered as
  // separate lines (matches what Harvest / Toggl enforce).
  if (hours > 24) {
    errors.putIfAbsent('hours', () => []).add('Cannot exceed 24h');
  }
  if (description.trim().isEmpty) {
    errors.putIfAbsent('description', () => []).add('Required');
  }
  // Same date guard as the leave form: no time travel.
  final today = DateTime.utc(now.year, now.month, now.day);
  final d = DateTime.utc(date.year, date.month, date.day);
  if (d.isAfter(today)) {
    errors.putIfAbsent('date', () => []).add('Cannot log future days');
  }
  if (errors.isNotEmpty) {
    throw ValidationFailure(fieldErrors: errors);
  }

  return TimesheetEntry(
    id: '', // assigned by repo
    employeeId: employeeId,
    employeeName: employeeName,
    projectId: projectId,
    projectName: projectName,
    date: d,
    hours: hours,
    description: description.trim(),
    status: TimesheetStatus.draft,
    taskId: taskId,
    taskTitle: taskTitle,
  );
}

/// Slice 8.2.2 — promote a draft to submitted (locks the entry from
/// further edits while it sits in the approval queue).
TimesheetEntry submitTimesheetEntry(TimesheetEntry entry) {
  if (entry.status != TimesheetStatus.draft) {
    throw ConflictFailure(message: 'Only drafts can be submitted');
  }
  return entry.copyWith(status: TimesheetStatus.submitted);
}
