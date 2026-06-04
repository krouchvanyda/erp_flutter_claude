import 'package:flutter/material.dart';

import 'package:erp_mobile/core/theme/app_font_size.dart';
import 'package:erp_mobile/core/theme/app_label.dart';
import 'package:erp_mobile/l10n/app_localizations.dart';

/// Placeholder for the "Settings" shell branch (Slice 2.1.1). Module 9
/// fills in real preference / admin / security pages.
class SettingsPlaceholderScreen extends StatelessWidget {
  const SettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: AppLabel(text: l10n.settingsTitle, fontSize: AppFontSize.value20),
      ),
      body: Center(
        child: AppLabel(
          text: l10n.settingsPlaceholder,
          fontSize: AppFontSize.value14,
        ),
      ),
    );
  }
}
