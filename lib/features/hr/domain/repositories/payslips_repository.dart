import '../entities/payslip.dart';

abstract class PayslipsRepository {
  Future<List<Payslip>> getForEmployee(String employeeId);
  Stream<List<Payslip>> watchForEmployee(String employeeId);
  Future<Payslip?> findById(String id);
}
