import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../domain/entities/payslip.dart';
import '../../domain/repositories/payslips_repository.dart';
import '../../domain/usecases/summarize_payslip.dart';

/// Slice 7.3.2 — payslip detail with line items grouped by kind.
///
/// **No real PDF**: the slice spec says "PDF preview" but we don't ship
/// a print engine in the demo binary. Show structured data instead and
/// surface a hint that the PDF will land with the server.
class PayslipDetailPage extends StatelessWidget {
  const PayslipDetailPage({super.key, required this.payslipId});
  final String payslipId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: 'Payslip Detail',
        centerTitle: true,
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                    theme.colorScheme.surface,
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
            FutureBuilder<Payslip?>(
              future: GetIt.I<PayslipsRepository>().findById(payslipId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final slip = snap.data;
                if (slip == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Text(
                          'No payslip with id "$payslipId".',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final buckets = summarizePayslip(slip);

                return ListView(
                  padding: EdgeInsets.only(
                    top: context.dynamicAppBarPadding + 16,
                    left: 16,
                    right: 16,
                    bottom: 40,
                  ),
                  children: [
                    // Main Slip Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slip.employeeName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_formatDate(slip.periodStart)}   ➔   ${_formatDate(slip.periodEnd)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28),

                          // Large Glowing Net Pay Highlight
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.teal,
                                  Colors.teal.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'NET PAYOUT',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatAmount(buckets.netPay),
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          _row(context, 'Basic Earnings', formatAmount(buckets.earnings)),
                          _row(context, 'Overtime Pay', formatAmount(buckets.overtime)),
                          _row(
                            context,
                            'Gross Pay',
                            formatAmount(buckets.grossPay),
                            bold: true,
                          ),
                          const Divider(height: 24),
                          _row(
                            context,
                            'Total Deductions',
                            '-${formatAmount(buckets.deductions)}',
                            isDeduction: true,
                          ),
                          _row(
                            context,
                            'Tax Withholdings',
                            '-${formatAmount(buckets.tax)}',
                            isDeduction: true,
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.05, end: 0, duration: 400.ms),
                    const SizedBox(height: 28),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'LINE ITEM BREAKDOWN',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    for (final kind in PayslipLineKind.values)
                      _KindGroup(
                        kind: kind,
                        lines: slip.lineItems.where((l) => l.kind == kind).toList(),
                      ).animate().fadeIn(duration: 300.ms),

                    const SizedBox(height: 20),

                    // Beautiful Info Banner for Server Preview Integration
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'PDF preview and download will land with the next server integration.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    bool isDeduction = false,
  }) {
    final theme = Theme.of(context);
    final displayColor = isDeduction
        ? theme.colorScheme.error
        : bold
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: bold ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w900 : FontWeight.bold,
              color: displayColor,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => dt.toIso8601String().split('T').first;
}

class _KindGroup extends StatelessWidget {
  const _KindGroup({required this.kind, required this.lines});
  final PayslipLineKind kind;
  final List<PayslipLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final Map<PayslipLineKind, Color> kindColors = {
      PayslipLineKind.earning: Colors.teal,
      PayslipLineKind.overtime: theme.colorScheme.primary,
      PayslipLineKind.deduction: Colors.orange,
      PayslipLineKind.tax: Colors.red,
    };
    final accentColor = kindColors[kind] ?? theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  kind.name.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final line in lines) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      line.amount,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: kind == PayslipLineKind.deduction || kind == PayslipLineKind.tax
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (line != lines.last)
                Divider(
                  height: 12,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
