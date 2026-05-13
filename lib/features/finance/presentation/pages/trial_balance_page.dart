import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/trial_balance_row.dart';
import '../../domain/repositories/trial_balance_repository.dart';
import '../../domain/usecases/paginate.dart';
import '../trial_balance_csv_share.dart';

/// Trial balance report (Slice 3.3.2) — paginated table with column
/// totals at the foot. The "Export CSV" AppBar action is wired by
/// Slice 3.3.3.
class TrialBalancePage extends StatefulWidget {
  const TrialBalancePage({super.key});

  @override
  State<TrialBalancePage> createState() => _TrialBalancePageState();
}

class _TrialBalancePageState extends State<TrialBalancePage> {
  static const _pageSize = 10;
  int _pageIndex = 0;
  late Future<List<TrialBalanceRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<TrialBalanceRepository>().getReport();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trialBalanceTitle),
        actions: [
          FutureBuilder<List<TrialBalanceRow>>(
            future: _future,
            builder: (context, snap) {
              final rows = snap.data ?? const <TrialBalanceRow>[];
              return IconButton(
                tooltip: l10n.trialBalanceExportCsvTooltip,
                icon: const Icon(Icons.file_download_outlined),
                onPressed: rows.isEmpty
                    ? null
                    : () => exportTrialBalanceCsv(context, rows),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<TrialBalanceRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? const <TrialBalanceRow>[];
          if (rows.isEmpty) {
            return Center(child: Text(l10n.trialBalanceEmpty));
          }
          final pageRows = paginate(
            rows,
            pageIndex: _pageIndex,
            pageSize: _pageSize,
          );
          final totalPages = pageCount(
            totalItems: rows.length,
            pageSize: _pageSize,
          );
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: [
                        DataColumn(label: Text(l10n.trialBalanceColumnCode)),
                        DataColumn(label: Text(l10n.trialBalanceColumnName)),
                        DataColumn(
                          label: Text(l10n.trialBalanceColumnDebit),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(l10n.trialBalanceColumnCredit),
                          numeric: true,
                        ),
                      ],
                      rows: [
                        for (final r in pageRows)
                          DataRow(cells: [
                            DataCell(Text(r.accountCode)),
                            DataCell(Text(r.accountName)),
                            DataCell(Text(r.debit)),
                            DataCell(Text(r.credit)),
                          ]),
                      ],
                    ),
                  ),
                ),
              ),
              _Pager(
                pageIndex: _pageIndex,
                totalPages: totalPages,
                onPrev: _pageIndex == 0
                    ? null
                    : () => setState(() => _pageIndex--),
                onNext: _pageIndex >= totalPages - 1
                    ? null
                    : () => setState(() => _pageIndex++),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.pageIndex,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  final int pageIndex;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(l10n.trialBalancePageOf(pageIndex + 1, totalPages)),
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
