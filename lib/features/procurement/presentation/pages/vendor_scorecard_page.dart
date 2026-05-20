import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/vendors_repository.dart';
import '../../entities/vendor.dart';
import '../../entities/vendor_scorecard.dart';

/// Vendor performance scorecard (Slice 4.3.3) — header + composite
/// gauge + breakdown rows. Math is delegated to
/// [`computeVendorScorecard`] so the page stays presentational.
class VendorScorecardPage extends StatelessWidget {
  const VendorScorecardPage({super.key, required this.vendorId});

  final String vendorId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repo = getIt<VendorsRepository>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vendorScorecardTitle)),
      body: FutureBuilder<_Bundle>(
        future: _load(repo),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final b = snap.data;
          if (b == null || b.vendor == null) {
            return Center(child: Text(l10n.vendorDetailNotFound(vendorId)));
          }
          return _Body(vendor: b.vendor!, scorecard: b.scorecard!);
        },
      ),
    );
  }

  Future<_Bundle> _load(VendorsRepository repo) async {
    final v = await repo.findById(vendorId);
    if (v == null) return const _Bundle(vendor: null, scorecard: null);
    final stats = await repo.performanceStatsFor(vendorId);
    return _Bundle(vendor: v, scorecard: computeVendorScorecard(stats));
  }
}

class _Bundle {
  const _Bundle({required this.vendor, required this.scorecard});
  final Vendor? vendor;
  final VendorScorecard? scorecard;
}

class _Body extends StatelessWidget {
  const _Body({required this.vendor, required this.scorecard});
  final Vendor vendor;
  final VendorScorecard scorecard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(vendor.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _GradePill(grade: scorecard.grade),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.vendorScorecardCompositeLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      Text(
                        scorecard.compositeScore.toStringAsFixed(1),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: scorecard.compositeScore / 100.0,
                        minHeight: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _MetricTile(
                label: l10n.vendorScorecardOnTimeLabel,
                value: '${scorecard.onTimeRatePct.toStringAsFixed(1)}%',
                color: theme.colorScheme.primary,
              ),
              const Divider(height: 0),
              _MetricTile(
                label: l10n.vendorScorecardDefectLabel,
                value: '${scorecard.defectRatePct.toStringAsFixed(1)}%',
                color: scorecard.defectRatePct > 5
                    ? theme.colorScheme.error
                    : theme.colorScheme.tertiary,
              ),
              const Divider(height: 0),
              _MetricTile(
                label: l10n.vendorScorecardDisputesLabel,
                value: scorecard.openDisputes.toString(),
                color: scorecard.openDisputes > 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.outline,
              ),
              const Divider(height: 0),
              _MetricTile(
                label: l10n.vendorScorecardSpendLabel,
                value: scorecard.totalSpend,
                color: theme.colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GradePill extends StatelessWidget {
  const _GradePill({required this.grade});
  final VendorGrade grade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (grade) {
      VendorGrade.a => theme.colorScheme.tertiary,
      VendorGrade.b => theme.colorScheme.primary,
      VendorGrade.c => theme.colorScheme.secondary,
      VendorGrade.d => theme.colorScheme.error,
    };
    final label = switch (grade) {
      VendorGrade.a => 'A',
      VendorGrade.b => 'B',
      VendorGrade.c => 'C',
      VendorGrade.d => 'D',
    };
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.displayMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: theme.textTheme.titleMedium?.copyWith(
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
