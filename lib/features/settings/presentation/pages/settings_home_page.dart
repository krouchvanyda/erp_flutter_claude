import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';

/// Module 9 settings hub. Groups every sub-page from Phases 9.1–9.3
/// into three sections so the user can scan the surface at a glance.
class SettingsHomePage extends StatelessWidget {
  const SettingsHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _Section(title: 'Preferences', children: [
            _Tile(
              icon: Icons.brightness_6_outlined,
              title: 'Appearance',
              subtitle: 'Light, dark, or follow system',
              routeName: RoutePaths.settingsAppearanceName,
            ),
            _Tile(
              icon: Icons.language_outlined,
              title: 'Language',
              subtitle: 'English / ខ្មែរ',
              routeName: RoutePaths.settingsLanguageName,
            ),
            _Tile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Push + email per category',
              routeName: RoutePaths.settingsNotificationsName,
            ),
          ]),
          _Section(title: 'Administration', children: [
            _Tile(
              icon: Icons.people_alt_outlined,
              title: 'User management',
              subtitle: 'Invite, suspend, assign roles',
              routeName: RoutePaths.settingsUsersName,
            ),
            _Tile(
              icon: Icons.shield_outlined,
              title: 'Roles & permissions',
              subtitle: 'Editor for custom roles',
              routeName: RoutePaths.settingsRolesName,
            ),
            _Tile(
              icon: Icons.cloud_outlined,
              title: 'API configuration',
              subtitle: 'Switch environment / tenant',
              routeName: RoutePaths.settingsApiConfigName,
            ),
          ]),
          _Section(title: 'Security', children: [
            _Tile(
              icon: Icons.devices_other_outlined,
              title: 'Active devices',
              subtitle: 'Sessions you can revoke',
              routeName: RoutePaths.settingsSessionsName,
            ),
            _Tile(
              icon: Icons.history_edu_outlined,
              title: 'Audit log',
              subtitle: 'Who did what, when',
              routeName: RoutePaths.settingsAuditLogName,
            ),
            _Tile(
              icon: Icons.lock_outline,
              title: 'App lock',
              subtitle: 'PIN + biometric re-auth',
              routeName: RoutePaths.settingsAppLockName,
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.routeName,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.pushNamed(routeName),
    );
  }
}
