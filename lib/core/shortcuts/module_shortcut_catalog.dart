import 'package:flutter/material.dart';

import '../../features/auth/entities/permission.dart';
import '../../features/chat/presentation/pages/chat_inbox_page.dart';
import '../../features/dashboard/presentation/pages/admin_demo_page.dart';
import '../../l10n/app_localizations.dart';
import 'module_shortcut.dart';

/// Single source of truth for the Modules grid (Slice 2.1.2).
///
/// Order is the on-screen order. Each tile carries a `requiredPermission`
/// (or `null` to mean "always visible to any signed-in user"); the
/// `permission_filter.dart` helper drops the ones the snapshot can't
/// satisfy before they reach the grid.
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

Widget _adminDemoPage() => const AdminDemoPage();
Widget _chatPage() => const ChatInboxPage();
