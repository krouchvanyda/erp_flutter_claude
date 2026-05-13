import '../entities/purchase_request.dart';

/// Domain contract for purchase request access (Phase 4.1).
abstract class PurchaseRequestsRepository {
  Future<List<PurchaseRequest>> getAll();
  Stream<List<PurchaseRequest>> watchAll();
  Future<PurchaseRequest?> findById(String id);

  /// Persists a status transition (Slice 4.1.3 approval workflow,
  /// Slice 4.2.2 conversion). Throws [StateError] on unknown id so the
  /// caller can surface a "PR is gone" message.
  Future<void> setStatus(String id, PurchaseRequestStatus newStatus);

  /// Adds a draft PR (Slice 4.1.2 form submit). Returns the persisted
  /// record (the repo assigns the id + number).
  Future<PurchaseRequest> create(PurchaseRequest draft);
}
