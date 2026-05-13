import 'dart:async';

import '../../domain/entities/sales_quotation.dart';
import '../../domain/repositories/quotations_repository.dart';
import '../sales_seed.dart';

class StubQuotationsRepository implements QuotationsRepository {
  StubQuotationsRepository();

  static final List<SalesQuotation> _seed =
      List<SalesQuotation>.of(SalesSeed.quotations);
  static int _idCounter = 100;

  final StreamController<List<SalesQuotation>> _changes =
      StreamController<List<SalesQuotation>>.broadcast();

  @override
  Future<List<SalesQuotation>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<SalesQuotation>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<SalesQuotation?> findById(String id) async {
    for (final q in _seed) {
      if (q.id == id) return q;
    }
    return null;
  }

  @override
  Future<SalesQuotation> create(SalesQuotation draft) async {
    _idCounter++;
    final id = 'qt-${_idCounter.toString().padLeft(3, '0')}';
    final number = 'QT-2026-${_idCounter.toString().padLeft(3, '0')}';
    final persisted = draft.copyWith(id: id, number: number);
    _seed.insert(0, persisted);
    _changes.add(List.unmodifiable(_seed));
    return persisted;
  }

  @override
  Future<SalesQuotation> setStatus(
      String id, QuotationStatus next) async {
    final idx = _seed.indexWhere((q) => q.id == id);
    if (idx == -1) throw StateError('Quotation "$id" not found');
    _seed[idx] = _seed[idx].copyWith(status: next);
    _changes.add(List.unmodifiable(_seed));
    return _seed[idx];
  }
}
