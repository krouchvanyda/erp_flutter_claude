import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Placeholder dashboard. Replaced in Module 2 with the real shell, drawer,
/// KPI tiles, etc. For Slice 0.1.3 it just confirms the auth-guarded route
/// rendered after a successful (stubbed) sign-in.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        actions: [
          if (onSignOut != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: onSignOut,
              tooltip: l10n.signOutTooltip,
            ),
        ],
      ),
      body: Center(
        child: Text(l10n.dashboardPlaceholder),
      ),
    );
  }
}
