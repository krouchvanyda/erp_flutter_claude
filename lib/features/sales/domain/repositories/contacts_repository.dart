import '../entities/contact.dart';

abstract class ContactsRepository {
  Future<List<CustomerContact>> forCustomer(String customerId);

  /// Persists a new contact (Slice 6.1.2). Returns the persisted row
  /// (the repo assigns the id).
  Future<CustomerContact> create(CustomerContact draft);

  /// Replaces an existing contact in place. Throws [StateError] when
  /// the id is unknown.
  Future<CustomerContact> update(CustomerContact updated);

  Future<void> delete(String contactId);
}
