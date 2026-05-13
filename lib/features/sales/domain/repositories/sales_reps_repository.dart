import '../entities/sales_rep.dart';

abstract class SalesRepsRepository {
  Future<List<SalesRep>> getAll();
  Future<SalesRep?> findById(String id);
}
