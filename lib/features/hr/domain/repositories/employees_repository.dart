import '../entities/employee.dart';

abstract class EmployeesRepository {
  Future<List<Employee>> getAll();
  Stream<List<Employee>> watchAll();
  Future<Employee?> findById(String id);
}
