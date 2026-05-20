import 'package:flutter/material.dart';

import '../../features/auth/entities/permission.dart';
import '../../l10n/app_localizations.dart';
import '../router/route_paths.dart';
import 'module_shortcut.dart';

/// Single source of truth for the Modules grid (Slice 2.1.2).
///
/// Order is the on-screen order. Each tile carries a `requiredPermission`
/// (or `null` to mean "always visible to any signed-in user"); the
/// `permission_filter.dart` helper drops the ones the snapshot can't
/// satisfy before they reach the grid.
///
/// **Coming-soon tiles** route to the shared [`/coming-soon/:label`]
/// page until their feature module lands. When a real route exists
/// (e.g. Slice 1.3.2's `/admin-demo`) the tile points there directly.
abstract final class ModuleShortcutCatalog {
  static const List<ModuleShortcut> all = [
    ModuleShortcut(
      id: 'admin-demo',
      icon: Icons.admin_panel_settings_outlined,
      labelOf: _adminDemoLabel,
      routeName: RoutePaths.adminDemoName,
      requiredPermission: Permission(token: 'admin'),
    ),
    ModuleShortcut(
      id: 'finance',
      icon: Icons.account_balance_outlined,
      labelOf: _financeLabel,
      // Slice 3.1.1 — Finance now routes to a real surface (chart of
      // accounts) instead of the generic coming-soon page.
      routeName: RoutePaths.chartOfAccountsName,
      requiredPermission: Permission(token: 'finance.*'),
    ),
    ModuleShortcut(
      id: 'procurement',
      icon: Icons.shopping_cart_outlined,
      labelOf: _procurementLabel,
      // Module 4 — flipped from `coming-soon` to the real PR list now
      // that all 8 procurement screens have shipped (Slices 4.1.1–4.3.3).
      routeName: RoutePaths.purchaseRequestListName,
      requiredPermission: Permission(token: 'procurement.*'),
    ),
    ModuleShortcut(
      id: 'inventory',
      icon: Icons.inventory_2_outlined,
      labelOf: _inventoryLabel,
      // Module 5 — flipped from `coming-soon` to the real list page
      // once Slice 5.1.1 (item catalog) shipped.
      routeName: RoutePaths.inventoryItemsName,
      requiredPermission: Permission(token: 'inventory.*'),
    ),
    ModuleShortcut(
      id: 'sales',
      icon: Icons.point_of_sale_outlined,
      labelOf: _salesLabel,
      // Module 6 — flipped from `coming-soon` to the real list page
      // once Slice 6.1.1 (customer catalog) shipped.
      routeName: RoutePaths.salesCustomersName,
      requiredPermission: Permission(token: 'sales.*'),
    ),
    ModuleShortcut(
      id: 'hr',
      icon: Icons.groups_outlined,
      labelOf: _hrLabel,
      // Module 7 — flipped from `coming-soon` to the real list page
      // once Slice 7.1.1 (employee directory) shipped.
      routeName: RoutePaths.hrEmployeesName,
      requiredPermission: Permission(token: 'hr.*'),
    ),
    ModuleShortcut(
      id: 'projects',
      icon: Icons.task_alt_outlined,
      labelOf: _projectsLabel,
      // Module 8 — flipped from `coming-soon` to the real list page
      // once Slice 8.1.1 (project list + Gantt) shipped.
      routeName: RoutePaths.projectListName,
      requiredPermission: Permission(token: 'projects.*'),
    ),
  ];
}

String _adminDemoLabel(AppLocalizations l) => l.shortcutAdminDemo;
String _financeLabel(AppLocalizations l) => l.shortcutFinance;
String _procurementLabel(AppLocalizations l) => l.shortcutProcurement;
String _inventoryLabel(AppLocalizations l) => l.shortcutInventory;
String _salesLabel(AppLocalizations l) => l.shortcutSales;
String _hrLabel(AppLocalizations l) => l.shortcutHr;
String _projectsLabel(AppLocalizations l) => l.shortcutProjects;
