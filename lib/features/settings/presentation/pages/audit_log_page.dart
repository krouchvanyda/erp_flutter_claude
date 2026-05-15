import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/audit_log_entry.dart';
import '../../domain/repositories/security_repositories.dart';
import '../../domain/usecases/query_audit_log.dart';

/// Slice 9.3.2 — read-only audit log with filter chips + search.
class AuditLogPage extends StatefulWidget {
  const AuditLogPage();

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final Set<AuditAction> _actionFilter = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final repo = GetIt.I<AuditLogRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: StreamBuilder<List<AuditLogEntry>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final visible = queryAuditLog(
            all,
            actionFilter: _actionFilter,
            searchQuery: _searchQuery,
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (q) => setState(() => _searchQuery = q),
                  decoration: InputDecoration(
                    hintText: 'Search actor, target, or detail…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: AuditAction.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, idx) {
                    final action = AuditAction.values[idx];
                    return FilterChip(
                      label: Text(action.name),
                      selected: _actionFilter.contains(action),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _actionFilter.add(action);
                        } else {
                          _actionFilter.remove(action);
                        }
                      }),
                    );
                  },
                ),
              ),
              if (visible.isEmpty)
                const Expanded(
                  child: Center(child: Text('No log entries match.')),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) =>
                        _LogEntryTile(entry: visible[idx]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});
  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _actionColor(entry.action),
        child: Icon(_actionIcon(entry.action), color: Colors.white),
      ),
      title: Text(
        '${entry.actorName} ${_actionVerb(entry.action)} ${entry.targetLabel}',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.targetType} • ${_fmt(entry.occurredAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (entry.detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                entry.detail!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Color _actionColor(AuditAction a) {
    switch (a) {
      case AuditAction.signIn:
      case AuditAction.signOut:
        return Colors.blueGrey;
      case AuditAction.approve:
      case AuditAction.create:
        return Colors.green.shade600;
      case AuditAction.reject:
      case AuditAction.delete:
        return Colors.red.shade600;
      case AuditAction.update:
        return Colors.blue.shade600;
      case AuditAction.permissionChange:
        return Colors.purple.shade500;
      case AuditAction.exportData:
        return Colors.orange.shade600;
    }
  }

  IconData _actionIcon(AuditAction a) {
    switch (a) {
      case AuditAction.signIn:
        return Icons.login;
      case AuditAction.signOut:
        return Icons.logout;
      case AuditAction.approve:
        return Icons.check;
      case AuditAction.reject:
        return Icons.close;
      case AuditAction.create:
        return Icons.add;
      case AuditAction.update:
        return Icons.edit;
      case AuditAction.delete:
        return Icons.delete;
      case AuditAction.permissionChange:
        return Icons.shield;
      case AuditAction.exportData:
        return Icons.file_download;
    }
  }

  String _actionVerb(AuditAction a) {
    switch (a) {
      case AuditAction.signIn:
        return 'signed into';
      case AuditAction.signOut:
        return 'signed out from';
      case AuditAction.approve:
        return 'approved';
      case AuditAction.reject:
        return 'rejected';
      case AuditAction.create:
        return 'created';
      case AuditAction.update:
        return 'updated';
      case AuditAction.delete:
        return 'deleted';
      case AuditAction.permissionChange:
        return 'changed permissions on';
      case AuditAction.exportData:
        return 'exported';
    }
  }

  String _fmt(DateTime dt) =>
      dt.toIso8601String().split('.').first.replaceFirst('T', ' ');
}
