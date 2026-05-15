import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/user_preferences.dart';
import '../../domain/repositories/preferences_repository.dart';

/// Slice 9.1.3 — push + email toggles per channel.
class NotificationPreferencesPage extends StatelessWidget {
  const NotificationPreferencesPage();

  @override
  Widget build(BuildContext context) {
    final repo = GetIt.I<PreferencesRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<UserPreferences>(
        stream: repo.watch(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final prefs = snap.data!.notificationChannels;
          return ListView(
            children: [
              for (final pref in prefs) _ChannelCard(pref: pref, repo: repo),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'System alerts always include critical security events; you cannot disable those.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.pref, required this.repo});
  final NotificationChannelPref pref;
  final PreferencesRepository repo;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon(pref.channel)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(pref.channel),
                        style:
                            const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _description(pref.channel),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Push'),
              value: pref.pushEnabled,
              onChanged: (v) => repo.setNotificationPref(
                pref.copyWith(pushEnabled: v),
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Email'),
              value: pref.emailEnabled,
              onChanged: (v) => repo.setNotificationPref(
                pref.copyWith(emailEnabled: v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(NotificationChannel c) {
    switch (c) {
      case NotificationChannel.approvals:
        return Icons.fact_check_outlined;
      case NotificationChannel.mentions:
        return Icons.alternate_email;
      case NotificationChannel.systemAlerts:
        return Icons.warning_amber_outlined;
      case NotificationChannel.marketing:
        return Icons.campaign_outlined;
    }
  }

  String _label(NotificationChannel c) {
    switch (c) {
      case NotificationChannel.approvals:
        return 'Approvals';
      case NotificationChannel.mentions:
        return 'Mentions & comments';
      case NotificationChannel.systemAlerts:
        return 'System alerts';
      case NotificationChannel.marketing:
        return 'Marketing & tips';
    }
  }

  String _description(NotificationChannel c) {
    switch (c) {
      case NotificationChannel.approvals:
        return 'Invoices, leave requests, timesheets pending your action';
      case NotificationChannel.mentions:
        return 'Someone @-mentioned you on a task or comment';
      case NotificationChannel.systemAlerts:
        return 'Sync failures, downtime windows, security';
      case NotificationChannel.marketing:
        return 'Product news, tips, and feature announcements';
    }
  }
}
