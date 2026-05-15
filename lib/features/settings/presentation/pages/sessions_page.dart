import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/device_session.dart';
import '../../domain/repositories/security_repositories.dart';
import '../../domain/usecases/manage_sessions.dart';

/// Slice 9.3.1 — active devices list with revoke actions.
class SessionsPage extends StatelessWidget {
  const SessionsPage();

  @override
  Widget build(BuildContext context) {
    final repo = GetIt.I<DeviceSessionsRepository>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active devices'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) async {
              if (action == 'revoke-others') {
                await repo.revokeAllOthers();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Other devices signed out.')),
                  );
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'revoke-others',
                child: Text('Sign out of all other devices'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<DeviceSession>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snap.data!;
          if (sessions.isEmpty) {
            return const Center(child: Text('No active sessions.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: sessions.length,
            itemBuilder: (_, idx) => _SessionCard(session: sessions[idx]),
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final DeviceSession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _platformIcon(session.platform),
                  color: session.isCurrent ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.deviceLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (session.isCurrent)
                            const Chip(
                              label: Text('This device'),
                              backgroundColor: Colors.greenAccent,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      Text(
                        session.platform,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _kv('Last active',
                _fmt(session.lastActiveAt, withTime: true)),
            _kv('Signed in', _fmt(session.signedInAt)),
            _kv('Location', session.location),
            if (session.ipAddress != null)
              _kv('IP', session.ipAddress!),
            if (!session.isCurrent) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.logout),
                  label: const Text('Revoke'),
                  onPressed: () => _revoke(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _revoke(BuildContext context) async {
    try {
      ensureSessionIsRevocable(session);
      await GetIt.I<DeviceSessionsRepository>().revoke(session.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${session.deviceLabel} signed out.')),
        );
      }
    } on ConflictFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message ?? 'Cannot revoke.')),
        );
      }
    }
  }

  Widget _kv(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  IconData _platformIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('android')) return Icons.android;
    if (p.contains('ios') || p.contains('ipad')) return Icons.phone_iphone;
    if (p.contains('mac') || p.contains('web')) return Icons.laptop_mac;
    return Icons.devices_other;
  }

  String _fmt(DateTime dt, {bool withTime = false}) {
    final iso = dt.toIso8601String();
    if (!withTime) return iso.split('T').first;
    return iso.split('.').first.replaceFirst('T', ' ');
  }
}
