import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../layout/responsive_breakpoint.dart';

/// One descriptor per shell destination — what icon, what label, what
/// branch index. Holding these centrally means the bottom bar, the rail,
/// and the drawer all read the same source.
class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l10n) label;
}

/// The destinations rendered in the shell, in branch order. Adding a new
/// branch is a two-line change: append here and append to the
/// `StatefulShellRoute` branches list in `AppRouter`.
const List<ShellDestination> _shellDestinations = [
  ShellDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: _homeLabel,
  ),
  ShellDestination(
    icon: Icons.apps_outlined,
    selectedIcon: Icons.apps,
    label: _modulesLabel,
  ),
  ShellDestination(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: _settingsLabel,
  ),
];

String _homeLabel(AppLocalizations l) => l.shellHome;
String _modulesLabel(AppLocalizations l) => l.shellModules;
String _settingsLabel(AppLocalizations l) => l.shellSettings;

/// Responsive shell wrapping the per-branch navigator from
/// [StatefulShellRoute.indexedStack].
///
/// **Chrome by window-size class** (Material 3):
/// - `compact`  (< 600 dp) — bottom [NavigationBar]
/// - `medium`   (600–839 dp) — collapsed [NavigationRail] beside content
/// - `expanded` (≥ 840 dp) — extended [NavigationRail] (text labels)
///   beside content
///
/// Branch state survives the layout swap because we only swap the
/// *chrome*; the [navigationShell] widget itself (which holds each
/// branch's IndexedStack) is reused across all three layouts.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Provided by [StatefulShellRoute.indexedStack]'s `navigatorContainerBuilder`
  /// — owns each branch's nested [Navigator] and the active-branch index.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final size = resolveWindowSizeClass(MediaQuery.sizeOf(context).width);
    return switch (size) {
      WindowSizeClass.compact => _buildCompact(context),
      WindowSizeClass.medium => _buildRail(context, extended: false),
      WindowSizeClass.expanded => _buildRail(context, extended: true),
    };
  }

  Scaffold _buildCompact(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: [
          for (final d in _shellDestinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label(l10n),
            ),
        ],
      ),
    );
  }

  Scaffold _buildRail(BuildContext context, {required bool extended}) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            extended: extended,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final d in _shellDestinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label(l10n)),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  /// `initialLocation: true` on the *same* tab pops back to the branch
  /// root (matches Material's "tap-the-active-tab-to-go-home" behavior).
  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
