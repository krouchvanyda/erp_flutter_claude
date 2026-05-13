import 'dart:async';

import '../../domain/entities/attendance_entry.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../hr_seed.dart';

class StubAttendanceRepository implements AttendanceRepository {
  StubAttendanceRepository();

  static final List<AttendanceEntry> _seed =
      List<AttendanceEntry>.of(HrSeed.attendance);

  final StreamController<List<AttendanceEntry>> _changes =
      StreamController<List<AttendanceEntry>>.broadcast();

  @override
  Future<List<AttendanceEntry>> getForEmployee(String employeeId) async {
    final out = _seed.where((e) => e.employeeId == employeeId).toList()
      ..sort((a, b) => b.clockIn.compareTo(a.clockIn));
    return List.unmodifiable(out);
  }

  @override
  Stream<List<AttendanceEntry>> watchForEmployee(String employeeId) async* {
    yield await getForEmployee(employeeId);
    yield* _changes.stream.map(
      (all) {
        final out = all.where((e) => e.employeeId == employeeId).toList()
          ..sort((a, b) => b.clockIn.compareTo(a.clockIn));
        return List<AttendanceEntry>.unmodifiable(out);
      },
    );
  }

  @override
  Future<AttendanceEntry?> latestFor(String employeeId) async {
    AttendanceEntry? best;
    for (final e in _seed) {
      if (e.employeeId != employeeId) continue;
      if (best == null || e.clockIn.isAfter(best.clockIn)) best = e;
    }
    return best;
  }

  @override
  Future<AttendanceEntry> create(AttendanceEntry entry) async {
    _seed.insert(0, entry);
    _emit();
    return entry;
  }

  @override
  Future<AttendanceEntry> update(AttendanceEntry entry) async {
    final idx = _seed.indexWhere((e) => e.id == entry.id);
    if (idx == -1) {
      _seed.insert(0, entry);
    } else {
      _seed[idx] = entry;
    }
    _emit();
    return entry;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_seed));
  }
}
