import 'dart:async';

import '../../domain/entities/employee.dart';
import '../../domain/repositories/employees_repository.dart';
import '../hr_seed.dart';

class StubEmployeesRepository implements EmployeesRepository {
  StubEmployeesRepository();

  static final List<Employee> _seed = List<Employee>.of(HrSeed.employees);

  final StreamController<List<Employee>> _changes =
      StreamController<List<Employee>>.broadcast();

  @override
  Future<List<Employee>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<Employee>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<Employee?> findById(String id) async {
    for (final e in _seed) {
      if (e.id == id) return e;
    }
    return null;
  }
}
