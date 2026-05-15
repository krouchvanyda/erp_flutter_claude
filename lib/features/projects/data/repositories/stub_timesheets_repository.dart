import 'dart:async';

import '../../domain/entities/timesheet_entry.dart';
import '../../domain/repositories/timesheets_repository.dart';
import '../projects_seed.dart';

class StubTimesheetsRepository implements TimesheetsRepository {
  StubTimesheetsRepository();

  static final List<TimesheetEntry> _seed =
      List<TimesheetEntry>.of(ProjectsSeed.timesheets);

  final StreamController<List<TimesheetEntry>> _changes =
      StreamController<List<TimesheetEntry>>.broadcast();

  @override
  Future<List<TimesheetEntry>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<TimesheetEntry>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<List<TimesheetEntry>> getForEmployee(String employeeId) async {
    final out = _seed.where((e) => e.employeeId == employeeId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(out);
  }

  @override
  Stream<List<TimesheetEntry>> watchForEmployee(String employeeId) async* {
    yield await getForEmployee(employeeId);
    yield* _changes.stream.map((all) {
      final out = all.where((e) => e.employeeId == employeeId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return List<TimesheetEntry>.unmodifiable(out);
    });
  }

  @override
  Future<TimesheetEntry?> findById(String id) async {
    for (final e in _seed) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<TimesheetEntry> create(TimesheetEntry entry) async {
    final id = entry.id.isEmpty
        ? 'ts-${DateTime.now().microsecondsSinceEpoch}'
        : entry.id;
    final stamped = entry.copyWith(id: id);
    _seed.insert(0, stamped);
    _emit();
    return stamped;
  }

  @override
  Future<TimesheetEntry> update(TimesheetEntry entry) async {
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
