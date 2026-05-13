import '../entities/customer.dart';

abstract class CustomersRepository {
  Future<List<Customer>> getAll();
  Stream<List<Customer>> watchAll();
  Future<Customer?> findById(String id);
}
