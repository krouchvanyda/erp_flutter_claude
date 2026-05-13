import '../../domain/entities/contact.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../sales_seed.dart';

class StubContactsRepository implements ContactsRepository {
  StubContactsRepository();

  static final List<CustomerContact> _seed =
      List<CustomerContact>.of(SalesSeed.contacts);
  static int _idCounter = 100;

  @override
  Future<List<CustomerContact>> forCustomer(String customerId) async {
    final list = _seed.where((c) => c.customerId == customerId).toList();
    // Primary first; then alphabetical by name.
    list.sort((a, b) {
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return List.unmodifiable(list);
  }

  @override
  Future<CustomerContact> create(CustomerContact draft) async {
    _idCounter++;
    // Enforce single-primary invariant per customer.
    if (draft.isPrimary) {
      for (var i = 0; i < _seed.length; i++) {
        if (_seed[i].customerId == draft.customerId && _seed[i].isPrimary) {
          _seed[i] = _seed[i].copyWith(isPrimary: false);
        }
      }
    }
    final persisted = draft.copyWith(id: 'ct-${_idCounter.toString().padLeft(3, '0')}');
    _seed.add(persisted);
    return persisted;
  }

  @override
  Future<CustomerContact> update(CustomerContact updated) async {
    final idx = _seed.indexWhere((c) => c.id == updated.id);
    if (idx == -1) throw StateError('Contact "${updated.id}" not found');
    if (updated.isPrimary) {
      for (var i = 0; i < _seed.length; i++) {
        if (i == idx) continue;
        if (_seed[i].customerId == updated.customerId &&
            _seed[i].isPrimary) {
          _seed[i] = _seed[i].copyWith(isPrimary: false);
        }
      }
    }
    _seed[idx] = updated;
    return updated;
  }

  @override
  Future<void> delete(String contactId) async {
    _seed.removeWhere((c) => c.id == contactId);
  }
}
