import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/attendance_entry.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/usecases/toggle_clock.dart';

/// Slice 7.3.1 — clock-in / clock-out + recent log.
///
/// The button text + colour follows whatever [resolveClockAction] would
/// do next given the latest entry, so the page truth is the use case,
/// not local UI state.
class AttendancePage extends StatefulWidget {
  const AttendancePage({this.employeeId = 'emp-001'});
  final String employeeId;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool _isSubmitting = false;
  String? _error;

  Future<void> _toggle() async {
    final repo = GetIt.I<AttendanceRepository>();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final latest = await repo.latestFor(widget.employeeId);
      final action = resolveClockAction(
        latest: latest,
        employeeId: widget.employeeId,
        now: DateTime.now(),
        newId: () => 'att-${DateTime.now().microsecondsSinceEpoch}',
      );
      switch (action) {
        case ClockInAction(:final draft):
          await repo.create(draft);
        case ClockOutAction(:final updated):
          await repo.update(updated);
      }
      if (mounted) setState(() {});
    } on ConflictFailure catch (f) {
      setState(() => _error = f.message ?? 'Conflict');
    } on ValidationFailure catch (f) {
      setState(() => _error =
          f.fieldErrors.values.expand((e) => e).join(', '));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = GetIt.I<AttendanceRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<AttendanceEntry?>(
            future: repo.latestFor(widget.employeeId),
            builder: (context, snap) {
              final latest = snap.data;
              final isOpen = latest?.isOpen ?? false;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        isOpen
                            ? Icons.timer_outlined
                            : Icons.timer_off_outlined,
                        size: 48,
                        color: isOpen ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isOpen ? 'Clocked in' : 'Clocked out',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (latest != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          isOpen
                              ? 'Since ${_fmt(latest.clockIn)}'
                              : 'Last out ${_fmt(latest.clockOut!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSubmitting ? null : _toggle,
                          icon: Icon(
                            isOpen ? Icons.logout : Icons.login,
                          ),
                          label: Text(
                            isOpen ? 'Clock Out' : 'Clock In',
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Recent entries',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<AttendanceEntry>>(
            stream: repo.watchForEmployee(widget.employeeId),
            builder: (context, snap) {
              final entries = snap.data ?? const <AttendanceEntry>[];
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No attendance yet.'),
                );
              }
              return Column(
                children: entries
                    .map((e) => _EntryTile(entry: e))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) =>
      dt.toIso8601String().split('.').first.replaceFirst('T', ' ');
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final AttendanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final hours = entry.workedMinutes / 60.0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          entry.isOpen
              ? Icons.timer_outlined
              : Icons.check_circle_outline,
          color: entry.isOpen ? Colors.green : Colors.grey,
        ),
        title: Text(entry.date.toIso8601String().split('T').first),
        subtitle: Text(
          entry.isOpen
              ? 'In ${_fmt(entry.clockIn)} (open)'
              : '${_fmt(entry.clockIn)} → ${_fmt(entry.clockOut!)}',
        ),
        trailing: entry.isOpen
            ? null
            : Text('${hours.toStringAsFixed(1)} h'),
      ),
    );
  }

  static String _fmt(DateTime dt) =>
      dt.toIso8601String().split('.').first.split('T').last.substring(0, 5);
}
