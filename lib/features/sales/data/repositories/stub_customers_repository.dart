import 'dart:async';

import '../../domain/entities/customer.dart';
import '../../domain/repositories/customers_repository.dart';
import '../sales_seed.dart';

class StubCustomersRepository implements CustomersRepository {
  StubCustomersRepository();

  static final List<Customer> _seed = List<Customer>.of(SalesSeed.customers);

  final StreamController<List<Customer>> _changes =
      StreamController<List<Customer>>.broadcast();

  @override
  Future<List<Customer>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<Customer>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<Customer?> findById(String id) async {
    for (final c in _seed) {
      if (c.id == id) return c;
    }
    return null;
  }
}
