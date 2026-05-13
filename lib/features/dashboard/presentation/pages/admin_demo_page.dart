import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Permission-gated demo destination wired up in Slice 1.3.2 so the
/// `RouteAccess` → `/forbidden` branch can be exercised end-to-end before
/// the real feature modules add their own gated routes.
///
/// `RouteAccess.requirements` declares this route requires `admin`; the
/// route guard reads `PermissionsSnapshot` and bounces unauthorised
/// users to [ForbiddenPage] before this widget ever builds.
class AdminDemoPage extends StatelessWidget {
  const AdminDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminDemoTitle)),
      body: Center(child: Text(l10n.adminDemoBody)),
    );
  }
}
