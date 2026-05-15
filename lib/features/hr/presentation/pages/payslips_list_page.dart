import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../domain/entities/payslip.dart';
import '../../domain/repositories/payslips_repository.dart';
import '../../domain/usecases/summarize_payslip.dart';

/// Slice 7.3.2 + 7.3.3 — payslip history with a period rollup card on
/// top so the user sees overtime / deductions at a glance without
/// drilling into individual slips.
class PayslipsListPage extends StatelessWidget {
  const PayslipsListPage({this.employeeId = 'emp-001'});
  final String employeeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payslips')),
      body: StreamBuilder<List<Payslip>>(
        stream: GetIt.I<PayslipsRepository>().watchForEmployee(employeeId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final slips = snap.data ?? const <Payslip>[];
          if (slips.isEmpty) {
            return const Center(child: Text('No payslips on file.'));
          }
          final summary = summarizePeriod(slips);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SummaryCard(buckets: summary, periods: slips.length),
              const SizedBox(height: 16),
              for (final slip in slips) _PayslipRow(slip: slip),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.buckets, required this.periods});
  final PayslipBuckets buckets;
  final int periods;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Period Summary ($periods slips)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _row('Earnings', formatAmount(buckets.earnings)),
            _row('Overtime', formatAmount(buckets.overtime)),
            _row('Deductions', '-${formatAmount(buckets.deductions)}'),
            _row('Tax', '-${formatAmount(buckets.tax)}'),
            const Divider(),
            _row(
              'Net pay',
              formatAmount(buckets.netPay),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
}

class _PayslipRow extends StatelessWidget {
  const _PayslipRow({required this.slip});
  final Payslip slip;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          '${slip.periodStart.toIso8601String().split('T').first} → '
          '${slip.periodEnd.toIso8601String().split('T').first}',
        ),
        subtitle: Text('Net ${slip.netPay} • Gross ${slip.grossPay}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.pushNamed(
          RoutePaths.hrPayslipDetailName,
          pathParameters: {RoutePaths.hrPayslipDetailIdParam: slip.id},
        ),
      ),
    );
  }
}
