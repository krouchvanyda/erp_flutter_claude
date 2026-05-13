import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/entities/sales_rep.dart';
import '../../domain/repositories/activities_repository.dart';
import '../../domain/repositories/sales_orders_repository.dart';
import '../../domain/repositories/sales_reps_repository.dart';
import '../../domain/usecases/revenue_by_period.dart';
import '../../domain/usecases/sales_rep_leaderboard.dart';
import '../../domain/usecases/top_rankings.dart';

/// Sales analytics page (Slices 6.3.1 + 6.3.2 + 6.3.3).
///
/// Three stacked sections:
///   1. Revenue chart — `fl_chart` bar chart with a weekly/monthly toggle.
///   2. Top customers + top products — side-by-side cards.
///   3. Sales rep leaderboard.
class SalesAnalyticsPage extends StatefulWidget {
  const SalesAnalyticsPage({super.key});

  @override
  State<SalesAnalyticsPage> createState() => _SalesAnalyticsPageState();
}

class _SalesAnalyticsPageState extends State<SalesAnalyticsPage> {
  late Future<_Bundle> _future;
  RevenuePeriod _period = RevenuePeriod.monthly;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Bundle> _load() async {
    final orders = await getIt<SalesOrdersRepository>().getAll();
    final orderActivities =
        await getIt<ActivitiesRepository>().allOfType(ActivityEventType.order);
    final reps = await getIt<SalesRepsRepository>().getAll();
    return _Bundle(
      orders: orders,
      orderActivities: orderActivities,
      reps: reps,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.salesAnalyticsTitle)),
      body: FutureBuilder<_Bundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final b = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RevenueChartCard(
                orders: b.orders,
                period: _period,
                onPeriodChanged: (p) => setState(() => _period = p),
              ),
              const SizedBox(height: 12),
              _TopRankingsRow(orders: b.orders),
              const SizedBox(height: 12),
              _LeaderboardCard(activities: b.orderActivities, reps: b.reps),
            ],
          );
        },
      ),
    );
  }
}

class _Bundle {
  const _Bundle({
    required this.orders,
    required this.orderActivities,
    required this.reps,
  });
  final List<SalesOrder> orders;
  final List<ActivityEvent> orderActivities;
  final List<SalesRep> reps;
}

// ── Revenue chart (Slice 6.3.1) ─────────────────────────────────

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({
    required this.orders,
    required this.period,
    required this.onPeriodChanged,
  });

  final List<SalesOrder> orders;
  final RevenuePeriod period;
  final ValueChanged<RevenuePeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Range: last 6 buckets ending in the *next* boundary so the
    // current week/month is included.
    final now = DateTime.now().toUtc();
    final (from, to) = _rangeFor(now, period);
    final buckets = revenueByPeriod(
      orders,
      period: period,
      from: from,
      to: to,
    );
    final maxRevenue = buckets.fold<num>(
      0,
      (m, b) => b.amount > m ? b.amount : m,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.salesAnalyticsRevenueHeading,
                      style: theme.textTheme.titleMedium),
                ),
                SegmentedButton<RevenuePeriod>(
                  segments: [
                    ButtonSegment(
                      value: RevenuePeriod.weekly,
                      label: Text(l10n.salesAnalyticsPeriodWeekly),
                    ),
                    ButtonSegment(
                      value: RevenuePeriod.monthly,
                      label: Text(l10n.salesAnalyticsPeriodMonthly),
                    ),
                  ],
                  selected: {period},
                  onSelectionChanged: (s) => onPeriodChanged(s.first),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (buckets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.salesAnalyticsRevenueEmpty,
                    style: theme.textTheme.bodySmall),
              )
            else
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (maxRevenue == 0 ? 1 : maxRevenue * 1.1).toDouble(),
                    barTouchData: BarTouchData(enabled: false),
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (v, meta) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= buckets.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _xLabel(buckets[idx].start, period),
                                style: theme.textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (v, meta) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              _compactCurrency(v),
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < buckets.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: buckets[i].amount.toDouble(),
                              color: theme.colorScheme.primary,
                              width: 16,
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static (DateTime, DateTime) _rangeFor(DateTime now, RevenuePeriod p) {
    switch (p) {
      case RevenuePeriod.weekly:
        // 6 weeks ending on the current week's Monday + 7 days.
        final daysFromMonday = (now.weekday - DateTime.monday) % 7;
        final thisMonday = DateTime.utc(now.year, now.month, now.day)
            .subtract(Duration(days: daysFromMonday));
        final from = thisMonday.subtract(const Duration(days: 7 * 5));
        final to = thisMonday.add(const Duration(days: 7));
        return (from, to);
      case RevenuePeriod.monthly:
        // 6 months ending the 1st of next month.
        final thisMonthStart = DateTime.utc(now.year, now.month, 1);
        // Walk back 5 months.
        var cursor = thisMonthStart;
        for (var i = 0; i < 5; i++) {
          final m = cursor.month == 1 ? 12 : cursor.month - 1;
          final y = cursor.month == 1 ? cursor.year - 1 : cursor.year;
          cursor = DateTime.utc(y, m, 1);
        }
        final nextMonth = thisMonthStart.month == 12 ? 1 : thisMonthStart.month + 1;
        final nextYear = thisMonthStart.month == 12
            ? thisMonthStart.year + 1
            : thisMonthStart.year;
        final to = DateTime.utc(nextYear, nextMonth, 1);
        return (cursor, to);
    }
  }

  static String _xLabel(DateTime start, RevenuePeriod p) {
    switch (p) {
      case RevenuePeriod.weekly:
        return DateFormat('MM-dd').format(start);
      case RevenuePeriod.monthly:
        return DateFormat('MMM').format(start);
    }
  }

  static String _compactCurrency(num v) {
    if (v.abs() >= 1000) {
      return '\$${(v / 1000).toStringAsFixed(0)}k';
    }
    return '\$${v.toStringAsFixed(0)}';
  }
}

// ── Top customers / top products (Slice 6.3.2) ──────────────────

class _TopRankingsRow extends StatelessWidget {
  const _TopRankingsRow({required this.orders});
  final List<SalesOrder> orders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customers = topCustomers(orders, limit: 5);
    final products = topProducts(orders, limit: 5);
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 600;
      final cards = [
        _RankingCard(
          title: l10n.salesAnalyticsTopCustomersHeading,
          icon: Icons.people_outline,
          entries: customers,
          emptyMessage: l10n.salesAnalyticsTopCustomersEmpty,
        ),
        _RankingCard(
          title: l10n.salesAnalyticsTopProductsHeading,
          icon: Icons.local_offer_outlined,
          entries: products,
          emptyMessage: l10n.salesAnalyticsTopProductsEmpty,
        ),
      ];
      if (isWide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        );
      }
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 12),
          cards[1],
        ],
      );
    });
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.icon,
    required this.entries,
    required this.emptyMessage,
  });

  final String title;
  final IconData icon;
  final List<TopRanking<String>> entries;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(emptyMessage, style: theme.textTheme.bodySmall),
            )
          else
            for (var i = 0; i < entries.length; i++)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary
                      .withValues(alpha: 0.15),
                  foregroundColor: theme.colorScheme.primary,
                  child: Text('${i + 1}',
                      style: theme.textTheme.labelSmall),
                ),
                title: Text(
                  entries[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${entries[i].units}',
                    style: theme.textTheme.labelSmall),
                trailing: Text(
                  entries[i].amount,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Leaderboard (Slice 6.3.3) ───────────────────────────────────

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.activities, required this.reps});

  final List<ActivityEvent> activities;
  final List<SalesRep> reps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final ranked = salesRepLeaderboard(activities, reps: reps);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l10n.salesAnalyticsLeaderboardHeading,
                    style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          if (ranked.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.salesAnalyticsLeaderboardEmpty,
                  style: theme.textTheme.bodySmall),
            )
          else
            for (final entry in ranked) _LeaderboardRow(entry: entry),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final attainmentColor = entry.attainmentPct >= 100
        ? theme.colorScheme.tertiary
        : entry.attainmentPct >= 60
            ? theme.colorScheme.primary
            : theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            foregroundColor: theme.colorScheme.primary,
            child: Text('${entry.rank}',
                style: theme.textTheme.titleSmall),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.rep.name, style: theme.textTheme.titleSmall),
                Text(
                  l10n.salesAnalyticsLeaderboardDealsLabel(
                    entry.dealsClosed.toString(),
                  ),
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (entry.attainmentPct / 100).clamp(0.0, 1.5),
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(attainmentColor),
                    minHeight: 6,
                  ),
                ),
                if (entry.rep.targetAmount.isNotEmpty)
                  Text(
                    l10n.salesAnalyticsLeaderboardAttainmentLabel(
                      entry.attainmentPct.toStringAsFixed(0),
                      entry.rep.targetAmount,
                    ),
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            entry.formattedRevenue,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
