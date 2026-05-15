import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/timesheet_entry.dart';
import '../../domain/repositories/timesheets_repository.dart';
import '../../domain/usecases/decide_timesheet.dart';
import '../../domain/usecases/submit_timesheet.dart';

/// Slice 8.2.1 + 8.2.2 — combined timesheets surface.
///
/// Three filter tabs:
/// - **Mine**: own entries (employee view — submit drafts here)
/// - **Approvals**: pending submitted entries from anyone (manager view)
/// - **All**: every entry — diagnostic / report view
class TimesheetsListPage extends StatefulWidget {
  const TimesheetsListPage({this.currentUserId = 'emp-001'});
  final String currentUserId;

  @override
  State<TimesheetsListPage> createState() => _TimesheetsListPageState();
}

enum _TsFilter { mine, approvals, all }

class _TimesheetsListPageState extends State<TimesheetsListPage> {
  _TsFilter _filter = _TsFilter.mine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timesheets'),
        actions: [
          IconButton(
            tooltip: 'Utilization',
            icon: const Icon(Icons.bar_chart),
            onPressed: () =>
                context.pushNamed(RoutePaths.timesheetUtilizationName),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SegmentedButton<_TsFilter>(
              segments: const [
                ButtonSegment(value: _TsFilter.mine, label: Text('Mine')),
                ButtonSegment(
                    value: _TsFilter.approvals,
                    label: Text('Approvals')),
                ButtonSegment(value: _TsFilter.all, label: Text('All')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) =>
                  setState(() => _filter = s.first),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<TimesheetEntry>>(
        stream: GetIt.I<TimesheetsRepository>().watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? const <TimesheetEntry>[];
          final visible = all.where(_match).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          if (visible.isEmpty) {
            return const Center(child: Text('No timesheet entries.'));
          }
          return ListView.separated(
            itemCount: visible.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, idx) => _EntryCard(
              entry: visible[idx],
              filter: _filter,
              currentUserId: widget.currentUserId,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RoutePaths.timesheetNewName),
        icon: const Icon(Icons.add),
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
    final canApprove = filter != _TsFilter.mine &&
        entry.status == TimesheetStatus.submitted;
    final canSubmit = filter == _TsFilter.mine &&
        entry.status == TimesheetStatus.draft &&
        entry.employeeId == currentUserId;
    final canReopen = filter == _TsFilter.mine &&
        entry.status == TimesheetStatus.rejected &&
        entry.employeeId == currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.employeeName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(
                  label: Text(entry.status.name),
                  backgroundColor: _statusColor(entry.status),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.projectName} • ${entry.hours}h • '
              '${entry.date.toIso8601String().split('T').first}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (entry.taskTitle != null) ...[
              const SizedBox(height: 2),
              Text(
                'Task: ${entry.taskTitle}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 6),
            Text(entry.description),
            if (entry.decisionNote != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Note: ${entry.decisionNote}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
            if (canApprove) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _reject(context),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _approve(context),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ] else if (canSubmit) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => _submit(context),
                    child: const Text('Submit for approval'),
                  ),
                ],
              ),
            ] else if (canReopen) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _reopen(context),
                    child: const Text('Re-open as draft'),
                  ),
                ],
              ),
            ],
          ],
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
        return Colors.grey.shade300;
      case TimesheetStatus.submitted:
        return Colors.orange.shade100;
      case TimesheetStatus.approved:
        return Colors.green.shade100;
      case TimesheetStatus.rejected:
        return Colors.red.shade100;
    }
  }
}
