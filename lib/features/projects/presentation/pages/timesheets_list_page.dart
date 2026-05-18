import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../domain/entities/timesheet_entry.dart';
import '../../domain/repositories/timesheets_repository.dart';
import '../../domain/usecases/decide_timesheet.dart';
import '../../domain/usecases/submit_timesheet.dart';

/// Slice 8.2.1 + 8.2.2 — combined timesheets surface.
class TimesheetsListPage extends StatefulWidget {
  const TimesheetsListPage({super.key, this.currentUserId = 'emp-001'});
  final String currentUserId;

  @override
  State<TimesheetsListPage> createState() => _TimesheetsListPageState();
}

enum _TsFilter { mine, approvals, all }

class _TimesheetsListPageState extends State<TimesheetsListPage> {
  _TsFilter _filter = _TsFilter.mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: 'Timesheets',
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Utilization',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () =>
                context.pushNamed(RoutePaths.timesheetUtilizationName),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<_TsFilter>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(value: _TsFilter.mine, label: Text('Mine')),
                ButtonSegment(
                  value: _TsFilter.approvals,
                  label: Text('Approvals'),
                ),
                ButtonSegment(value: _TsFilter.all, label: Text('All')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) =>
                  setState(() => _filter = s.first),
            ),
          ),
        ),
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
            StreamBuilder<List<TimesheetEntry>>(
              stream: GetIt.I<TimesheetsRepository>().watchAll(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? const <TimesheetEntry>[];
                final visible = all.where(_match).toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
                if (visible.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 48,
                          color: theme.colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No timesheet entries found.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.only(
                    top: context.dynamicAppBarPadding + 36,
                    left: 16,
                    right: 16,
                    bottom: 80,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (_, idx) => _EntryCard(
                    entry: visible[idx],
                    filter: _filter,
                    currentUserId: widget.currentUserId,
                  ).animate().fadeIn(delay: (idx * 50).ms).slideY(begin: 0.05, end: 0, duration: 250.ms),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RoutePaths.timesheetNewName),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log time'),
      ),
    );
  }

  bool _match(TimesheetEntry e) {
    switch (_filter) {
      case _TsFilter.mine:
        return e.employeeId == widget.currentUserId;
      case _TsFilter.approvals:
        return e.status == TimesheetStatus.submitted;
      case _TsFilter.all:
        return true;
    }
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.filter,
    required this.currentUserId,
  });

  final TimesheetEntry entry;
  final _TsFilter filter;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(entry.status);

    final canApprove = filter != _TsFilter.mine &&
        entry.status == TimesheetStatus.submitted;
    final canSubmit = filter == _TsFilter.mine &&
        entry.status == TimesheetStatus.draft &&
        entry.employeeId == currentUserId;
    final canReopen = filter == _TsFilter.mine &&
        entry.status == TimesheetStatus.rejected &&
        entry.employeeId == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      entry.employeeName.isEmpty ? '?' : entry.employeeName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.employeeName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      entry.status.name.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.projectName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${entry.hours} Hours',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: theme.colorScheme.outline),
                  const SizedBox(width: 6),
                  Text(
                    entry.date.toIso8601String().split('T').first,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (entry.taskTitle != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined, size: 12, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Task: ${entry.taskTitle}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                entry.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
              if (entry.decisionNote != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    'Rejection Note: ${entry.decisionNote}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              if (canApprove) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                      ),
                      onPressed: () => _reject(context),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                      ),
                      onPressed: () => _approve(context),
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ] else if (canSubmit) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 14),
                      onPressed: () => _submit(context),
                      label: const Text('Submit for Approval'),
                    ),
                  ],
                ),
              ] else if (canReopen) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                      ),
                      icon: const Icon(Icons.replay_rounded, size: 14),
                      onPressed: () => _reopen(context),
                      label: const Text('Re-open as Draft'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    try {
      final updated = approveTimesheetEntry(
        entry: entry,
        approverId: currentUserId,
        now: DateTime.now(),
      );
      await GetIt.I<TimesheetsRepository>().update(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timesheet approved.')),
        );
      }
    } on ConflictFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message ?? 'Cannot approve.')),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject timesheet'),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, reasonCtrl.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    try {
      final updated = rejectTimesheetEntry(
        entry: entry,
        approverId: currentUserId,
        now: DateTime.now(),
        reason: reason,
      );
      await GetIt.I<TimesheetsRepository>().update(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timesheet rejected.')),
        );
      }
    } on ValidationFailure {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A reason is required.')),
        );
      }
    } on ConflictFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message ?? 'Cannot reject.')),
        );
      }
    }
  }

  Future<void> _submit(BuildContext context) async {
    try {
      final updated = submitTimesheetEntry(entry);
      await GetIt.I<TimesheetsRepository>().update(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for approval.')),
        );
      }
    } on ConflictFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message ?? 'Cannot submit.')),
        );
      }
    }
  }

  Future<void> _reopen(BuildContext context) async {
    try {
      final updated = reopenRejectedTimesheet(entry);
      await GetIt.I<TimesheetsRepository>().update(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reopened as draft.')),
        );
      }
    } on ConflictFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message ?? 'Cannot reopen.')),
        );
      }
    }
  }

  Color _statusColor(TimesheetStatus s) {
    switch (s) {
      case TimesheetStatus.draft:
        return Colors.grey;
      case TimesheetStatus.submitted:
        return Colors.orange;
      case TimesheetStatus.approved:
        return Colors.green;
      case TimesheetStatus.rejected:
        return Colors.red;
    }
  }
}
