import 'package:erp_mobile/shared/widgets/app_background_gradient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/router/config_router.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import 'api_config_page.dart';
import 'app_lock_page.dart';
import 'appearance_page.dart';
import 'audit_log_page.dart';
import 'language_page.dart';
import 'my_profile_page.dart';
import 'my_roles_page.dart';
import 'notification_preferences_page.dart';
import 'role_editor_page.dart';
import 'sessions_page.dart';
import 'user_management_page.dart';

/// Module 9 settings hub. Groups every sub-page from Phases 9.1–9.3
/// into three sections so the user can scan the surface at a glance.
class SettingsHomePage extends StatelessWidget {
  const SettingsHomePage({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const DynamicAppBar(title: 'Settings', centerTitle: true),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            // Background Canvas
            AppBackgroundGradient(),
            ListView(
              padding: EdgeInsets.only(
                top: context.dynamicAppBarPadding + 60,
                left: 16,
                right: 16,
                bottom: 100,
              ),
              children: [

                // Account Group — Slices 9.1.4 / 9.1.5.
                _Section(
                  title: 'Account',
                  children: [
                    _Tile(
                      icon: Icons.person_outline,
                      title: 'My profile',
                      subtitle: 'Contact, personal, security',
                      page: const MyProfilePage(),
                      color: Colors.deepPurple,
                    ),
                    const Divider(height: 1, indent: 56),
                    _Tile(
                      icon: Icons.shield_outlined,
                      title: 'My roles & permissions',
                      subtitle: 'What you can do in the app',
                      page: const MyRolesPage(),
                      color: Colors.cyan.shade700,
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 80.ms)
                    .slideY(begin: 0.05, end: 0, duration: 300.ms),

                const SizedBox(height: 20),

                // Preferences Group
                _Section(
                      title: 'Preferences',
                      children: [
                        _Tile(
                          icon: Icons.brightness_6_outlined,
                          title: 'Appearance',
                          subtitle: 'Light, dark, or follow system',
                          page: const AppearancePage(),
                          color: Colors.blue,
                        ),
                        const Divider(height: 1, indent: 56),
                        _Tile(
                          icon: Icons.language_outlined,
                          title: 'Language',
                          subtitle: 'English / ខ្មែរ',
                          page: const LanguagePage(),
                          color: Colors.indigo,
                        ),
                        const Divider(height: 1, indent: 56),
                        _Tile(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          subtitle: 'Push + email per category',
                          page: const NotificationPreferencesPage(),
                          color: Colors.amber.shade800,
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(delay: 100.ms)
                    .slideY(begin: 0.05, end: 0, duration: 300.ms),

                const SizedBox(height: 20),

                // Security Group
                _Section(
                      title: 'Security & Access',
                      children: [
                        _Tile(
                          icon: Icons.devices_other_outlined,
                          title: 'Active devices',
                          subtitle: 'Sessions you can revoke',
                          page: const SessionsPage(),
                          color: Colors.teal,
                        ),
                        const Divider(height: 1, indent: 56),
                        _Tile(
                          icon: Icons.history_edu_outlined,
                          title: 'Audit log',
                          subtitle: 'Who did what, when',
                          page: const AuditLogPage(),
                          color: Colors.deepPurple,
                        ),
                        const Divider(height: 1, indent: 56),
                        _Tile(
                          icon: Icons.lock_outline,
                          title: 'App lock',
                          subtitle: 'PIN + biometric re-auth',
                          page: const AppLockPage(),
                          color: Colors.pink,
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .slideY(begin: 0.05, end: 0, duration: 300.ms),

                const SizedBox(height: 20),

                // Administration Group
                _Section(
                      title: 'Administration',
                      children: [
                        _Tile(
                          icon: Icons.people_alt_outlined,
                          title: 'User management',
                          subtitle: 'Invite, suspend, assign roles',
                          page: const UserManagementPage(),
                          color: Colors.orange.shade700,
                        ),
                        const Divider(height: 1, indent: 56),
                        _Tile(
                          icon: Icons.shield_outlined,
                          title: 'Roles & permissions',
                          subtitle: 'Editor for custom roles',
                          page: const RoleEditorPage(),
                          color: Colors.cyan.shade700,
                        ),
                        const Divider(height: 1, indent: 56),
                        _Tile(
                          icon: Icons.cloud_outlined,
                          title: 'API configuration',
                          subtitle: 'Switch environment / tenant',
                          page: const ApiConfigPage(),
                          color: Colors.blueGrey,
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .slideY(begin: 0.05, end: 0, duration: 300.ms),

                Container(
                  margin: EdgeInsets.only(bottom: 16, top: 16),
                  child: Center(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.errorContainer,
                        foregroundColor: theme.colorScheme.onErrorContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ),
              ],
            ),
          ],
        ),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        size: 16,
      ),
      onTap: () => ConfigRouter.pushPageAnimation(context, page),
    );
  }
}
