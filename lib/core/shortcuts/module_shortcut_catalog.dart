import 'package:flutter/material.dart';

import '../../features/auth/entities/permission.dart';
import '../../features/dashboard/presentation/pages/admin_demo_page.dart';
import '../../features/finance/presentation/pages/chart_of_accounts_page.dart';
import '../../features/hr/presentation/pages/employee_list_page.dart';
import '../../features/inventory/presentation/pages/items_list_page.dart';
import '../../features/procurement/presentation/pages/pr_list_page.dart';
import '../../features/projects/presentation/pages/project_list_page.dart';
import '../../features/sales/presentation/pages/customer_list_page.dart';
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
    ModuleShortcut(
      id: 'finance',
      icon: Icons.account_balance_outlined,
      labelOf: _financeLabel,
      builder: _financePage,
      requiredPermission: Permission(token: 'finance.*'),
    ),
    ModuleShortcut(
      id: 'procurement',
      icon: Icons.shopping_cart_outlined,
      labelOf: _procurementLabel,
      builder: _procurementPage,
      requiredPermission: Permission(token: 'procurement.*'),
    ),
    ModuleShortcut(
      id: 'inventory',
      icon: Icons.inventory_2_outlined,
      labelOf: _inventoryLabel,
      builder: _inventoryPage,
      requiredPermission: Permission(token: 'inventory.*'),
    ),
    ModuleShortcut(
      id: 'sales',
      icon: Icons.point_of_sale_outlined,
      labelOf: _salesLabel,
      builder: _salesPage,
      requiredPermission: Permission(token: 'sales.*'),
    ),
    ModuleShortcut(
      id: 'hr',
      icon: Icons.groups_outlined,
      labelOf: _hrLabel,
      builder: _hrPage,
      requiredPermission: Permission(token: 'hr.*'),
    ),
    ModuleShortcut(
      id: 'projects',
      icon: Icons.task_alt_outlined,
      labelOf: _projectsLabel,
      builder: _projectsPage,
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

Widget _adminDemoPage() => const AdminDemoPage();
Widget _financePage() => const ChartOfAccountsPage();
Widget _procurementPage() => const PurchaseRequestListPage();
Widget _inventoryPage() => const ItemsListPage();
Widget _salesPage() => const CustomerListPage();
Widget _hrPage() => const EmployeeListPage();
Widget _projectsPage() => const ProjectListPage();
