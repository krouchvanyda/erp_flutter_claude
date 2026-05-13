import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/layout/responsive_breakpoint.dart';
import '../../../../core/router/permissions_snapshot.dart';
import '../../../../core/shortcuts/module_shortcut.dart';
import '../../../../core/shortcuts/module_shortcut_catalog.dart';
import '../../../../core/shortcuts/permission_filter.dart';
import '../../../../features/search/presentation/widgets/global_search_anchor.dart';
import '../../../../l10n/app_localizations.dart';

/// Modules grid (Slice 2.1.2): permission-filtered shortcut tiles to
/// every feature module the signed-in user can reach.
///
/// Reads [PermissionsSnapshot] reactively (same source as the route
/// guard from 1.3.2 and `PermissionGuard` from 1.3.3) so granting or
/// revoking a role flips tiles in / out without a manual refresh.
///
/// Column count tracks `WindowSizeClass` via `gridColumnsFor` — 2 / 3 / 4
/// for compact / medium / expanded — matching the rest of the responsive
/// shell.
class ModulesPage extends StatelessWidget {
  const ModulesPage({super.key, PermissionsSnapshot? snapshot})
      : _snapshotOverride = snapshot;

  /// Test seam — production code lets the page resolve via `getIt`.
  final PermissionsSnapshot? _snapshotOverride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final permissions = _snapshotOverride ?? getIt<PermissionsSnapshot>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.modulesTitle),
        actions: const [GlobalSearchAnchor()],
      ),
      body: ListenableBuilder(
        listenable: permissions,
        builder: (context, _) {
          final visible = filterByPermission<ModuleShortcut>(
            ModuleShortcutCatalog.all,
            (s) => s.requiredPermission,
            permissions.permissions,
          ).toList(growable: false);

          if (visible.isEmpty) return _EmptyState(label: l10n.modulesEmpty);

          final size =
              resolveWindowSizeClass(MediaQuery.sizeOf(context).width);
          final columns = gridColumnsFor(size);
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: visible.length,
            itemBuilder: (context, i) =>
                _ShortcutTile(shortcut: visible[i], l10n: l10n),
          );
        },
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.shortcut, required this.l10n});

  final ModuleShortcut shortcut;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.goNamed(
          shortcut.routeName,
          pathParameters: shortcut.pathParameters,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                shortcut.icon,
                size: 36,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                shortcut.labelOf(l10n),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
