import '../entities/timesheet_entry.dart';

/// Slice 8.2.3 — bucketed utilization for the report chart.
///
/// `loggedHours` is the sum of approved time entries inside `[from, to]`.
/// `targetHours` defaults to 8 hours/day × number of weekdays in the
/// window, which is what the chart uses as the 100% baseline. The
/// caller can override `hoursPerDay` for orgs on a different schedule.
class UtilizationBucket {
  const UtilizationBucket({
    required this.employeeId,
    required this.employeeName,
    required this.loggedHours,
    required this.targetHours,
  });

  final String employeeId;
  final String employeeName;
  final double loggedHours;
  final double targetHours;

  /// Percent of target. Capped at 0 when target is zero so the bar
  /// chart never blows up on a holiday-only window.
  double get utilizationPct =>
      targetHours <= 0 ? 0 : (loggedHours / targetHours) * 100.0;
}

List<UtilizationBucket> computeUtilization({
  required List<TimesheetEntry> entries,
  required DateTime from,
  required DateTime to,
  double hoursPerDay = 8.0,
  bool approvedOnly = true,
}) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  if (end.isBefore(start)) return const [];

  // Sum hours per employee inside the window.
  final byEmployee = <String, ({String name, double hours})>{};
  for (final e in entries) {
    if (approvedOnly && e.status != TimesheetStatus.approved) continue;
    final d = DateTime.utc(e.date.year, e.date.month, e.date.day);
    if (d.isBefore(start) || d.isAfter(end)) continue;
    final prior = byEmployee[e.employeeId];
    byEmployee[e.employeeId] = (
      name: e.employeeName,
      hours: (prior?.hours ?? 0) + e.hours.toDouble(),
    );
  }

  final target = countWeekdays(start, end) * hoursPerDay;

  final out = <UtilizationBucket>[];
  for (final entry in byEmployee.entries) {
    out.add(UtilizationBucket(
      employeeId: entry.key,
      employeeName: entry.value.name,
      loggedHours: entry.value.hours,
      targetHours: target,
    ));
  }
  // Highest utilization first — same convention as the sales rep
  // leaderboard (Slice 6.3.3).
  out.sort((a, b) => b.utilizationPct.compareTo(a.utilizationPct));
  return out;
}

/// Mon–Fri count between [start, end] inclusive.
int countWeekdays(DateTime start, DateTime end) {
  var count = 0;
  for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
    if (d.weekday >= DateTime.monday && d.weekday <= DateTime.friday) {
      count++;
    }
  }
  return count;
}
