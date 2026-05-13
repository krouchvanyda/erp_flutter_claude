import '../../domain/entities/account.dart';
import '../../domain/entities/trial_balance_row.dart';
import '../../domain/repositories/accounts_repository.dart';
import '../../domain/repositories/trial_balance_repository.dart';

/// Builds a trial balance report off the chart-of-accounts seed
/// (Slice 3.3.2).
///
/// **Why composes the accounts repo instead of seeding fresh**: keeps
/// the demo numbers consistent — an account's `formattedBalance` shown
/// in the tree view (Slice 3.1.1) matches its row in the report.
/// Real impl will hit a server-side aggregator that respects period
/// boundaries.
class StubTrialBalanceRepository implements TrialBalanceRepository {
  StubTrialBalanceRepository({required AccountsRepository accounts})
      : _accounts = accounts;

  final AccountsRepository _accounts;

  @override
  Future<List<TrialBalanceRow>> getReport() async {
    final all = await _accounts.getAll();
    final rows = <TrialBalanceRow>[];
    // Roll up only leaf accounts (those with a formatted balance).
    // Roll-ups would aggregate children — out of scope for the stub.
    for (final a in all) {
      final bal = a.formattedBalance;
      if (bal == null) continue;
      final isDebitNormal = a.type == AccountType.asset ||
          a.type == AccountType.expense;
      rows.add(TrialBalanceRow(
        accountId: a.id,
        accountCode: a.code,
        accountName: a.name,
        accountType: a.type,
        debit: isDebitNormal ? bal : r'$0.00',
        credit: isDebitNormal ? r'$0.00' : bal,
      ));
    }
    rows.sort((x, y) => x.accountCode.compareTo(y.accountCode));
    return rows;
  }
}
