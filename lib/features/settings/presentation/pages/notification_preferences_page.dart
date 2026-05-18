import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../domain/entities/user_preferences.dart';
import '../../domain/repositories/preferences_repository.dart';

/// Slice 9.1.3 — push + email toggles per channel.
class NotificationPreferencesPage extends StatelessWidget {
  const NotificationPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = GetIt.I<PreferencesRepository>();
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const DynamicAppBar(
        title: 'Notifications',
        centerTitle: true,
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            // Background Canvas
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
            StreamBuilder<UserPreferences>(
              stream: repo.watch(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final prefs = snap.data!.notificationChannels;
                return ListView(
                  padding: EdgeInsets.only(
                    top: context.dynamicAppBarPadding,
                    left: 16,
                    right: 16,
                    bottom: 40,
                  ),
                  children: [
                    Text(
                      'NOTIFICATION CHANNELS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (int i = 0; i < prefs.length; i++) ...[
                      _ChannelCard(pref: prefs[i], repo: repo)
                          .animate()
                          .fadeIn(delay: (i * 80).ms)
                          .slideY(begin: 0.04, end: 0, duration: 300.ms),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'System alerts always include critical security events; you cannot disable those.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 350.ms),
                  ],
                );
              },
            ),
          ],
        ),
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
    final theme = Theme.of(context);
    final isSystem = pref.channel == NotificationChannel.systemAlerts;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _color(pref.channel).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(
                  _icon(pref.channel),
                  color: _color(pref.channel),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(pref.channel),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _description(pref.channel),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          SwitchListTile(
            dense: true,
            activeColor: theme.colorScheme.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(
              'Push Notifications',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            value: pref.pushEnabled,
            onChanged: isSystem
                ? null
                : (v) => repo.setNotificationPref(
                      pref.copyWith(pushEnabled: v),
                    ),
          ),
          SwitchListTile(
            dense: true,
            activeColor: theme.colorScheme.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(
              'Email Updates',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            value: pref.emailEnabled,
            onChanged: isSystem
                ? null
                : (v) => repo.setNotificationPref(
                      pref.copyWith(emailEnabled: v),
                    ),
          ),
        ],
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

  Color _color(NotificationChannel c) {
    switch (c) {
      case NotificationChannel.approvals:
        return Colors.green;
      case NotificationChannel.mentions:
        return Colors.blue;
      case NotificationChannel.systemAlerts:
        return Colors.red;
      case NotificationChannel.marketing:
        return Colors.amber.shade800;
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
        return 'Invoices, leave requests, timesheets pending action';
      case NotificationChannel.mentions:
        return 'Someone @-mentioned you on a task or comment';
      case NotificationChannel.systemAlerts:
        return 'Sync failures, downtime windows, security events';
      case NotificationChannel.marketing:
        return 'Product news, tips, and feature announcements';
    }
  }
}
