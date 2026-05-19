import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../layout/responsive_breakpoint.dart';
import '../widgets/dynamic_status_bar.dart';

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

const List<ShellDestination> _shellDestinations = [
  ShellDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: _homeLabel,
  ),
  ShellDestination(
    icon: Icons.apps_outlined,
    selectedIcon: Icons.apps_rounded,
    label: _modulesLabel,
  ),
  ShellDestination(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    label: _settingsLabel,
  ),
];

String _homeLabel(AppLocalizations l) => l.shellHome;
String _modulesLabel(AppLocalizations l) => l.shellModules;
String _settingsLabel(AppLocalizations l) => l.shellSettings;

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final size = resolveWindowSizeClass(MediaQuery.sizeOf(context).width);
    return DynamicStatusBar(
      child: switch (size) {
        WindowSizeClass.compact => _buildCompact(context),
        WindowSizeClass.medium => _buildRail(context, extended: false),
        WindowSizeClass.expanded => _buildRail(context, extended: true),
      },
    );
  }

  Scaffold _buildCompact(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBody: true, // Crucial for floating nav bar
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 72,
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (int i = 0; i < _shellDestinations.length; i++)
                      _BottomNavItem(
                        destination: _shellDestinations[i],
                        isSelected: navigationShell.currentIndex == i,
                        onTap: () => _goBranch(i),
                        label: _shellDestinations[i].label(l10n),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Scaffold _buildRail(BuildContext context, {required bool extended}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            extended: extended,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.1),
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
          VerticalDivider(
            thickness: 1, 
            width: 1, 
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
    required this.label,
  });

  final ShellDestination destination;
  final bool isSelected;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primary.withValues(alpha: 0.1) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? destination.selectedIcon : destination.icon,
              color: isSelected 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.onSurfaceVariant,
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
