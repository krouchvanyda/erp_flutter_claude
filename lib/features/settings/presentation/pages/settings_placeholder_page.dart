import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Placeholder for the "Settings" shell branch (Slice 2.1.1). Module 9
/// fills in real preference / admin / security pages.
class SettingsPlaceholderPage extends StatelessWidget {
  const SettingsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Center(child: Text(l10n.settingsPlaceholder)),
    );
  }
}
