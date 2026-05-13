import '../entities/transaction.dart';

/// Domain contract for ledger transaction access (Slice 3.1.2).
///
/// **Per-account watch as the primary read** — the detail page reads
/// only one account at a time, so a query indexed by `accountId` is
/// the cheap path. A future "all activity" inbox would add a separate
/// global watch rather than overload this one.
///
/// **Newest-first ordering** is the source's responsibility (drift
/// `ORDER BY postedAt DESC` in Slice 3.1.3); the bloc / page render
/// in the order received.
abstract class TransactionsRepository {
  /// One-shot snapshot of every line posted against [accountId].
  Future<List<LedgerTransaction>> getByAccount(String accountId);

  /// Reactive variant — emits a fresh list whenever a line is posted /
  /// reversed / cached for [accountId]. Drives the detail page so a
  /// real-time push updates the table without manual refresh.
  Stream<List<LedgerTransaction>> watchByAccount(String accountId);
}
