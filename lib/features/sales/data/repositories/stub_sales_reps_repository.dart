import '../../domain/entities/sales_rep.dart';
import '../../domain/repositories/sales_reps_repository.dart';
import '../sales_seed.dart';

class StubSalesRepsRepository implements SalesRepsRepository {
  StubSalesRepsRepository();

  static final List<SalesRep> _seed = List<SalesRep>.of(SalesSeed.reps);

  @override
  Future<List<SalesRep>> getAll() async => List.unmodifiable(_seed);

  @override
  Future<SalesRep?> findById(String id) async {
    for (final r in _seed) {
      if (r.id == id) return r;
    }
    return null;
  }
}
