import '../../domain/entities/account.dart';
import '../../domain/repositories/accounts_repository.dart';
import '../datasources/accounts_dao.dart';
import '../finance_seed.dart';

/// Drift-backed [AccountsRepository] (Slice 3.1.3) — replaces the in-
/// memory stub with a persistent cache that survives app restart and
/// works offline.
///
/// **Lazy seed**: on first call, if the cache is empty, the bootstrap
/// writes [`FinanceSeed.accounts`]. Avoids a separate "did the user
/// install the app today?" flag in `app_metadata` — the table itself
/// is the source of truth.
class DriftAccountsRepository implements AccountsRepository {
  DriftAccountsRepository({required AccountsDao dao}) : _dao = dao;

  final AccountsDao _dao;
  Future<void>? _bootstrap;

  Future<void> _ensureBootstrapped() {
    return _bootstrap ??= _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    final count = await _dao.countAccounts();
    if (count > 0) return;
    await _dao.upsertAccounts(FinanceSeed.accounts);
  }

  @override
  Future<List<Account>> getAll() async {
    await _ensureBootstrapped();
    return _dao.getAllAccounts();
  }

  @override
  Stream<List<Account>> watchAll() async* {
    await _ensureBootstrapped();
    yield* _dao.watchAllAccounts();
  }

  @override
  Future<Account?> findById(String id) async {
    await _ensureBootstrapped();
    return _dao.findAccountById(id);
  }
}
