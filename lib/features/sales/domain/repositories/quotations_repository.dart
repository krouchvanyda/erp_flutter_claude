import '../entities/sales_quotation.dart';

abstract class QuotationsRepository {
  Future<List<SalesQuotation>> getAll();
  Stream<List<SalesQuotation>> watchAll();
  Future<SalesQuotation?> findById(String id);

  /// Persists a new quotation (Slice 6.2.1 form submit). Returns the
  /// persisted row (the repo assigns id + number).
  Future<SalesQuotation> create(SalesQuotation draft);

  /// Flips status without touching line items (Slice 6.2.2 marks a
  /// quotation as `converted`).
  Future<SalesQuotation> setStatus(String id, QuotationStatus next);
}
