import 'dart:async';

import '../../domain/entities/leave_request.dart';
import '../../domain/repositories/leave_requests_repository.dart';
import '../hr_seed.dart';

class StubLeaveRequestsRepository implements LeaveRequestsRepository {
  StubLeaveRequestsRepository();

  static final List<LeaveRequest> _seed =
      List<LeaveRequest>.of(HrSeed.leaveRequests);

  final StreamController<List<LeaveRequest>> _changes =
      StreamController<List<LeaveRequest>>.broadcast();

  @override
  Future<List<LeaveRequest>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<LeaveRequest>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<LeaveRequest?> findById(String id) async {
    for (final r in _seed) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<LeaveRequest> create(LeaveRequest request) async {
    final id = request.id.isEmpty ? 'lv-${DateTime.now().microsecondsSinceEpoch}' : request.id;
    final stamped = request.copyWith(id: id);
    _seed.insert(0, stamped);
    _emit();
    return stamped;
  }

  @override
  Future<LeaveRequest> update(LeaveRequest request) async {
    final idx = _seed.indexWhere((r) => r.id == request.id);
    if (idx == -1) {
      _seed.insert(0, request);
    } else {
      _seed[idx] = request;
    }
    _emit();
    return request;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_seed));
  }
}

class StubLeaveBalancesRepository implements LeaveBalancesRepository {
  StubLeaveBalancesRepository();

  static final List<LeaveBalance> _seed =
      List<LeaveBalance>.of(HrSeed.leaveBalances);

  final StreamController<List<LeaveBalance>> _changes =
      StreamController<List<LeaveBalance>>.broadcast();

  @override
  Future<List<LeaveBalance>> getForEmployee(String employeeId) async =>
      List.unmodifiable(_seed.where((b) => b.employeeId == employeeId));

  @override
  Stream<List<LeaveBalance>> watchForEmployee(String employeeId) async* {
    yield await getForEmployee(employeeId);
    yield* _changes.stream
        .map((all) => all.where((b) => b.employeeId == employeeId).toList());
  }
}
