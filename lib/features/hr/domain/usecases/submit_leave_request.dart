import '../../../../core/error/failure.dart';
import '../entities/leave_request.dart';

/// Slice 7.2.1 — validates a draft request before it enters the
/// "pending" queue. Pure-Dart so the form bloc + the API receiver can
/// both reuse it.
///
/// Throws [ValidationFailure] with field-level errors on bad input.
/// Returns the canonical (status-stamped) [LeaveRequest] on success;
/// the repository is responsible for assigning the id.
LeaveRequest validateLeaveRequest({
  required String employeeId,
  required String employeeName,
  required LeaveType type,
  required DateTime fromDate,
  required DateTime toDate,
  required String reason,
  required DateTime now,
}) {
  final errors = <String, List<String>>{};
  if (employeeId.isEmpty) {
    errors.putIfAbsent('employeeId', () => []).add('Required');
  }
  // Strip time of day — leave is a calendar-date concept.
  final from = DateTime.utc(fromDate.year, fromDate.month, fromDate.day);
  final to = DateTime.utc(toDate.year, toDate.month, toDate.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  if (to.isBefore(from)) {
    errors.putIfAbsent('toDate', () => []).add('Must be on or after the start date');
  }
  if (from.isBefore(today)) {
    errors.putIfAbsent('fromDate', () => []).add('Cannot request past dates');
  }
  if (reason.trim().isEmpty) {
    errors.putIfAbsent('reason', () => []).add('Required');
  }
  if (errors.isNotEmpty) {
    throw ValidationFailure(fieldErrors: errors);
  }

  return LeaveRequest(
    id: '', // assigned by repo
    employeeId: employeeId,
    employeeName: employeeName,
    type: type,
    fromDate: from,
    toDate: to,
    reason: reason.trim(),
    status: LeaveRequestStatus.pending,
    requestedAt: now,
  );
}
