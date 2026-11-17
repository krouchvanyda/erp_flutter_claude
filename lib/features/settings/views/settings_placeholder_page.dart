import 'package:flutter/material.dart';
import 'package:get/get.dart' show Trans;

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';

/// Placeholder for the "Settings" shell branch (Slice 2.1.1). Module 9
/// fills in real preference / admin / security pages.
class SettingsPlaceholderPage extends StatelessWidget {
  const SettingsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppLabel(text: 'settingsTitle'.tr, fontSize: AppFontSize.value20),
      ),
      body: Center(
        child: AppLabel(
          text: 'settingsPlaceholder'.tr,
          fontSize: AppFontSize.value14,
        ),
      ),
    );
  }
}
