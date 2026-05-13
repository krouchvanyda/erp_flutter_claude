import '../../../../core/error/failure.dart';
import '../entities/leave_request.dart';

/// Slice 7.2.3 — manager actions over a pending request.
///
/// State-machine guard: both [approve] and [reject] throw
/// [ConflictFailure] when the request is no longer pending. The result
/// is a new [LeaveRequest] stamped with the decision metadata so the
/// repository can swap it in atomically.
LeaveRequest approveLeaveRequest({
  required LeaveRequest request,
  required String approverId,
  required DateTime now,
  String? note,
}) {
  if (request.status != LeaveRequestStatus.pending) {
    throw ConflictFailure(message: 'Already ${request.status.name}');
  }
  return request.copyWith(
    status: LeaveRequestStatus.approved,
    approvedBy: approverId,
    actionedAt: now,
    decisionNote: note,
  );
}

LeaveRequest rejectLeaveRequest({
  required LeaveRequest request,
  required String approverId,
  required DateTime now,
  required String reason,
}) {
  if (request.status != LeaveRequestStatus.pending) {
    throw ConflictFailure(message: 'Already ${request.status.name}');
  }
  if (reason.trim().isEmpty) {
    // Match the procurement-side pattern: rejection reason is mandatory
    // at the domain level, not just the form.
    throw ValidationFailure(fieldErrors: {
      'reason': ['Required'],
    });
  }
  return request.copyWith(
    status: LeaveRequestStatus.rejected,
    approvedBy: approverId,
    actionedAt: now,
    decisionNote: reason.trim(),
  );
}

/// Employee-side action — only the requester can cancel, and only while
/// the request is still pending. We don't enforce "only the requester"
/// here (that's a permissions concern) but the state guard is universal.
LeaveRequest cancelLeaveRequest({
  required LeaveRequest request,
  required DateTime now,
}) {
  if (request.status != LeaveRequestStatus.pending) {
    throw ConflictFailure(message: 'Already ${request.status.name}');
  }
  return request.copyWith(
    status: LeaveRequestStatus.cancelled,
    actionedAt: now,
  );
}
