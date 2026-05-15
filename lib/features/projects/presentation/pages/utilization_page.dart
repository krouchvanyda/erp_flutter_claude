import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/timesheet_entry.dart';
import '../../domain/repositories/timesheets_repository.dart';
import '../../domain/usecases/compute_utilization.dart';

/// Slice 8.2.3 — utilization report.
///
/// Bar chart of approved hours per employee against the weekday-based
/// target for the selected window. Window toggles between "this week"
/// and "this month" without leaving the page.
class UtilizationPage extends StatefulWidget {
  const UtilizationPage();

  @override
  State<UtilizationPage> createState() => _UtilizationPageState();
}

enum _Window { week, month }

class _UtilizationPageState extends State<UtilizationPage> {
  _Window _window = _Window.week;

  ({DateTime from, DateTime to}) _range(DateTime now) {
    if (_window == _Window.week) {
      // Monday-anchored.
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      return (
        from: DateTime.utc(monday.year, monday.month, monday.day),
        to: DateTime.utc(sunday.year, sunday.month, sunday.day),
      );
    }
    final firstOfMonth = DateTime.utc(now.year, now.month, 1);
    final firstNext = DateTime.utc(now.year, now.month + 1, 1);
    final lastOfMonth = firstNext.subtract(const Duration(days: 1));
    return (from: firstOfMonth, to: lastOfMonth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilization')),
      body: StreamBuilder<List<TimesheetEntry>>(
        stream: GetIt.I<TimesheetsRepository>().watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? const <TimesheetEntry>[];
          final r = _range(DateTime.now());
          final buckets = computeUtilization(
            entries: entries,
            from: r.from,
            to: r.to,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<_Window>(
                segments: const [
                  ButtonSegment(
                      value: _Window.week, label: Text('This week')),
                  ButtonSegment(
                      value: _Window.month, label: Text('This month')),
                ],
                selected: {_window},
                onSelectionChanged: (s) =>
                    setState(() => _window = s.first),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Approved hours vs target',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.from.toIso8601String().split('T').first} → '
                        '${r.to.toIso8601String().split('T').first}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      if (buckets.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No approved hours in this window.'),
                          ),
                        )
                      else
                        SizedBox(
                          height: 240,
                          child: _UtilizationBarChart(buckets: buckets),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    for (final b in buckets) _LeaderRow(bucket: b),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UtilizationBarChart extends StatelessWidget {
  const _UtilizationBarChart({required this.buckets});
  final List<UtilizationBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final maxY = buckets.fold<double>(
      0,
      (m, b) => b.loggedHours > m ? b.loggedHours : m,
    );
    // Pad the y-axis so the tallest bar isn't flush with the top.
    final yMax = (maxY == 0 ? 8.0 : maxY * 1.2).ceilToDouble();

    return BarChart(
      BarChartData(
        maxY: yMax,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: yMax / 4,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= buckets.length) {
                  return const SizedBox.shrink();
                }
                final name = buckets[idx].employeeName;
                final short = name.split(' ').first;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    short,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].loggedHours,
                  width: 18,
                  color: _utilizationColor(buckets[i].utilizationPct),
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _utilizationColor(double pct) {
    if (pct >= 100) return Colors.green.shade600;
    if (pct >= 75) return Colors.blue.shade500;
    if (pct >= 50) return Colors.amber.shade600;
    return Colors.red.shade400;
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.bucket});
  final UtilizationBucket bucket;

  @override
  Widget build(BuildContext context) {
    final pct = bucket.utilizationPct.clamp(0.0, 200.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bucket.employeeName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${bucket.loggedHours.toStringAsFixed(1)}h '
                '/ ${bucket.targetHours.toStringAsFixed(0)}h '
                '(${pct.toStringAsFixed(0)}%)',
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }
}
