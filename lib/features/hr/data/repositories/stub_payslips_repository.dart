import 'dart:async';

import '../../domain/entities/payslip.dart';
import '../../domain/repositories/payslips_repository.dart';
import '../hr_seed.dart';

class StubPayslipsRepository implements PayslipsRepository {
  StubPayslipsRepository();

  static final List<Payslip> _seed = List<Payslip>.of(HrSeed.payslips);

  final StreamController<List<Payslip>> _changes =
      StreamController<List<Payslip>>.broadcast();

  @override
  Future<List<Payslip>> getForEmployee(String employeeId) async {
    final out = _seed.where((p) => p.employeeId == employeeId).toList()
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
    return List.unmodifiable(out);
  }

  @override
  Stream<List<Payslip>> watchForEmployee(String employeeId) async* {
    yield await getForEmployee(employeeId);
    yield* _changes.stream.map(
      (all) {
        final out = all.where((p) => p.employeeId == employeeId).toList()
          ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
        return List<Payslip>.unmodifiable(out);
      },
    );
  }

  @override
  Future<Payslip?> findById(String id) async {
    for (final p in _seed) {
      if (p.id == id) return p;
    }
    return null;
  }
}
