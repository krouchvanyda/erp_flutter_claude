import '../entities/account.dart';

/// Domain contract for the chart-of-accounts source (Slice 3.1.1).
///
/// **Returns flat lists, not pre-built trees**: the tree shape is a
/// presentation concern that varies by view (Module 3 wants the full
/// hierarchy; a future "favourites" widget might want a flat top-N).
/// Callers run [`buildAccountTree`] over the result when they want the
/// hierarchical shape.
///
/// **Reactivity**: [watchAll] emits a fresh list on every cache update
/// (Slice 3.1.3 wires the drift watch). `getAll` is the one-shot
/// equivalent for non-reactive callers.
abstract class AccountsRepository {
  /// One-shot snapshot of the full account list.
  Future<List<Account>> getAll();

  /// Reactive variant — emits a fresh list whenever the underlying
  /// cache (or future remote sync) writes.
  Stream<List<Account>> watchAll();

  /// Single-account lookup. Returns `null` when the id isn't cached.
  /// Used by the account-detail page (Slice 3.1.2).
  Future<Account?> findById(String id);
}
