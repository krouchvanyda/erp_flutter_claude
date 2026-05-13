import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transactions_repository.dart';
import '../datasources/accounts_dao.dart';
import '../finance_seed.dart';

/// Drift-backed [TransactionsRepository] (Slice 3.1.3).
///
/// Same lazy-bootstrap pattern as [DriftAccountsRepository]. Seeded
/// from [`FinanceSeed.transactions`] so the chart-of-accounts demo
/// stays populated across cold starts. The DAO's `account_id` FK
/// requires the accounts seed to land first — bootstrap waits on the
/// supplied `bootstrapAccounts` future for that ordering.
class DriftTransactionsRepository implements TransactionsRepository {
  DriftTransactionsRepository({
    required AccountsDao dao,
    required Future<void> Function() bootstrapAccounts,
  })  : _dao = dao,
        _bootstrapAccounts = bootstrapAccounts;

  final AccountsDao _dao;
  final Future<void> Function() _bootstrapAccounts;
  Future<void>? _bootstrap;

  Future<void> _ensureBootstrapped() {
    return _bootstrap ??= _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    // Accounts must exist first — FK constraint.
    await _bootstrapAccounts();
    // Reuse the dao's per-account query as a cheap "is the seed in?"
    // probe — we know one of the seed account ids has lines.
    final probe = await _dao.getTransactionsByAccount('a-1110');
    if (probe.isNotEmpty) return;
    await _dao.upsertTransactions(FinanceSeed.transactions);
  }

  @override
  Future<List<LedgerTransaction>> getByAccount(String accountId) async {
    await _ensureBootstrapped();
    return _dao.getTransactionsByAccount(accountId);
  }

  @override
  Stream<List<LedgerTransaction>> watchByAccount(String accountId) async* {
    await _ensureBootstrapped();
    yield* _dao.watchTransactionsByAccount(accountId);
  }
}
