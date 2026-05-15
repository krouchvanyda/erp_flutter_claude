import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/repositories/leave_requests_repository.dart';
import '../../domain/usecases/decide_leave_request.dart';

/// Slice 7.2.3 — manager view of pending leave requests with
/// approve / reject actions. Mine vs. Pending toggle keeps the same
/// page useful for employees too.
class LeaveRequestsListPage extends StatefulWidget {
  const LeaveRequestsListPage({this.currentUserId = 'emp-001'});
  final String currentUserId;

  @override
  State<LeaveRequestsListPage> createState() => _LeaveRequestsListPageState();
}

enum _Filter { all, pending, mine }

class _LeaveRequestsListPageState extends State<LeaveRequestsListPage> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SegmentedButton<_Filter>(
              segments: const [
                ButtonSegment(value: _Filter.all, label: Text('All')),
                ButtonSegment(
                  value: _Filter.pending,
                  label: Text('Pending'),
                ),
                ButtonSegment(value: _Filter.mine, label: Text('Mine')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) =>
                  setState(() => _filter = s.first),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New request',
            icon: const Icon(Icons.add),
            onPressed: () =>
                context.pushNamed(RoutePaths.hrLeaveRequestNewName),
          ),
        ],
      ),
      body: StreamBuilder<List<LeaveRequest>>(
        stream: GetIt.I<LeaveRequestsRepository>().watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data ?? const <LeaveRequest>[];
          final visible = all.where(_match).toList();
          if (visible.isEmpty) {
            return const Center(child: Text('No leave requests.'));
          }
          return ListView.separated(
            itemCount: visible.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, idx) =>
                _RequestCard(request: visible[idx], approverId: widget.currentUserId),
          );
        },
      ),
    );
  }

  bool _match(LeaveRequest r) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.pending:
        return r.status == LeaveRequestStatus.pending;
      case _Filter.mine:
        return r.employeeId == widget.currentUserId;
    }
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.approverId});
  final LeaveRequest request;
  final String approverId;

  @override
  Widget build(BuildContext context) {
    final canAct = request.status == LeaveRequestStatus.pending;
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
                    request.employeeName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(
                  label: Text(request.status.name),
                  backgroundColor: _statusColor(request.status),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${request.type.name} • ${request.days} day(s) • '
              '${request.fromDate.toIso8601String().split('T').first} → '
              '${request.toDate.toIso8601String().split('T').first}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (request.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(request.reason),
            ],
            if (canAct) ...[
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
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    final repo = GetIt.I<LeaveRequestsRepository>();
    try {
      final updated = approveLeaveRequest(
        request: request,
        approverId: approverId,
        now: DateTime.now(),
      );
      await repo.update(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave approved.')),
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
        title: const Text('Reject leave'),
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
      final updated = rejectLeaveRequest(
        request: request,
        approverId: approverId,
        now: DateTime.now(),
        reason: reason,
      );
      await GetIt.I<LeaveRequestsRepository>().update(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave rejected.')),
        );
      }
    } on ValidationFailure {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A rejection reason is required.')),
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

  Color _statusColor(LeaveRequestStatus s) {
    switch (s) {
      case LeaveRequestStatus.pending:
        return Colors.orange.shade100;
      case LeaveRequestStatus.approved:
        return Colors.green.shade100;
      case LeaveRequestStatus.rejected:
        return Colors.red.shade100;
      case LeaveRequestStatus.cancelled:
        return Colors.grey.shade300;
    }
  }
}
