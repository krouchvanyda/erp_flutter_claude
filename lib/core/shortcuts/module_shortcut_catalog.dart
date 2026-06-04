import 'package:flutter/material.dart';

import 'package:erp_mobile/features/authentication/models/permission_model.dart';
import 'package:erp_mobile/features/chat/views/chat_inbox_screen.dart';
import 'package:erp_mobile/features/dashboard/views/admin_demo_screen.dart';
import 'package:erp_mobile/l10n/app_localizations.dart';
import 'package:erp_mobile/core/shortcuts/module_shortcut.dart';

/// Single source of truth for the Modules grid (Slice 2.1.2).
///
/// Order is the on-screen order. Each tile carries a `requiredPermission`
/// (or `null` to mean "always visible to any signed-in user"); the
/// `permission_filter.dart` helper drops the ones the snapshot can't
/// satisfy before they reach the grid.
///
/// Note: the Finance / Procurement / Inventory / Sales / HR / Projects
/// modules were removed — only the admin-demo and Chat tiles remain.
abstract final class ModuleShortcutCatalog {
  static const List<ModuleShortcut> all = [
    ModuleShortcut(
      id: 'admin-demo',
      icon: Icons.admin_panel_settings_outlined,
      labelOf: _adminDemoLabel,
      builder: _adminDemoPage,
      requiredPermission: Permission(token: 'admin'),
    ),
    // Module 10 — Chat is ungated; every signed-in user can message.
    // Label is hardcoded until the chat ARB keys land.
    ModuleShortcut(
      id: 'chat',
      icon: Icons.chat_bubble_outline_rounded,
      labelOf: _chatLabel,
      builder: _chatPage,
    ),
  ];
}

String _adminDemoLabel(AppLocalizations l) => l.shortcutAdminDemo;
// Module 10 — hardcoded until the chat ARB key lands.
String _chatLabel(AppLocalizations l) => 'Chat';

Widget _adminDemoPage() => const AdminDemoScreen();
Widget _chatPage() => const ChatInboxScreen();
