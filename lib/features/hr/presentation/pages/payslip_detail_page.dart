import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/payslip.dart';
import '../../domain/repositories/payslips_repository.dart';
import '../../domain/usecases/summarize_payslip.dart';

/// Slice 7.3.2 — payslip detail with line items grouped by kind.
///
/// **No real PDF**: the slice spec says "PDF preview" but we don't ship
/// a print engine in the demo binary. Show structured data instead and
/// surface a hint that the PDF will land with the server.
class PayslipDetailPage extends StatelessWidget {
  const PayslipDetailPage({required this.payslipId});
  final String payslipId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payslip')),
      body: FutureBuilder<Payslip?>(
        future: GetIt.I<PayslipsRepository>().findById(payslipId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final slip = snap.data;
          if (slip == null) {
            return Center(
              child: Text('No payslip with id "$payslipId".'),
            );
          }
          final buckets = summarizePayslip(slip);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slip.employeeName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${slip.periodStart.toIso8601String().split('T').first} → '
                        '${slip.periodEnd.toIso8601String().split('T').first}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(height: 24),
                      _row('Earnings', formatAmount(buckets.earnings)),
                      _row('Overtime', formatAmount(buckets.overtime)),
                      _row(
                        'Gross pay',
                        formatAmount(buckets.grossPay),
                        bold: true,
                      ),
                      const SizedBox(height: 8),
                      _row(
                        'Deductions',
                        '-${formatAmount(buckets.deductions)}',
                      ),
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
              ),
              const SizedBox(height: 24),
              Text(
                'Line items',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final kind in PayslipLineKind.values)
                _KindGroup(
                  kind: kind,
                  lines:
                      slip.lineItems.where((l) => l.kind == kind).toList(),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PDF preview will land with the server integration.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _row(String label, String value, {bool bold = false}) =>
      Padding(
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

class _KindGroup extends StatelessWidget {
  const _KindGroup({required this.kind, required this.lines});
  final PayslipLineKind kind;
  final List<PayslipLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kind.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(line.label)),
                    Text(line.amount),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
