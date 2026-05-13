import '../entities/leave_request.dart';

abstract class LeaveRequestsRepository {
  Future<List<LeaveRequest>> getAll();
  Stream<List<LeaveRequest>> watchAll();
  Future<LeaveRequest?> findById(String id);

  /// Slice 7.2.1 — create a pending request.
  Future<LeaveRequest> create(LeaveRequest request);

  /// Slice 7.2.3 — replaces in-place. Caller is responsible for valid
  /// state transitions (use the use cases, not this directly).
  Future<LeaveRequest> update(LeaveRequest request);
}

abstract class LeaveBalancesRepository {
  Future<List<LeaveBalance>> getForEmployee(String employeeId);
  Stream<List<LeaveBalance>> watchForEmployee(String employeeId);
}
