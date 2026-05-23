import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_font_size.dart';
import '../../../../core/theme/app_label.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../../../shared/widgets/app_background_gradient.dart';
import '../../data/permission_catalog.dart';
import '../../data/repositories/admin_repositories.dart';
import '../../data/repositories/my_profile_repository.dart';
import '../../entities/managed_user.dart';
import '../../entities/my_profile.dart';

/// Slice 9.1.5 — My Roles & Permissions.
///
/// Read-only transparency view: shows which roles the signed-in user
/// has been assigned, and which of the catalogued permission scopes
/// are granted versus not. Users can't modify their own roles here —
/// that goes through the admin role editor (Slice 9.2.2). A search
/// box filters both lists by human label, module, or raw token so
/// "what does inventory.* actually let me do?" stays one tap away.
class MyRolesPage extends StatefulWidget {
  const MyRolesPage({super.key});

  @override
  State<MyRolesPage> createState() => _MyRolesPageState();
}

class _MyRolesPageState extends State<MyRolesPage> {
  final _profileRepo = GetIt.I<MyProfileRepository>();
  final _usersRepo = GetIt.I<ManagedUsersRepository>();
  final _rolesRepo = GetIt.I<RolesRepository>();

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const DynamicAppBar(
        title: 'My Roles & Permissions',
        centerTitle: true,
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            const AppBackgroundGradient(),
            StreamBuilder<MyProfile>(
              stream: _profileRepo.watch(),
              builder: (context, profileSnap) {
                if (!profileSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profile = profileSnap.data!;
                return FutureBuilder<_RoleViewModel>(
                  future: _load(profile.id),
                  builder: (context, vmSnap) {
                    if (!vmSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _Body(
                      vm: vmSnap.data!,
                      searchCtrl: _searchCtrl,
                      query: _query,
                      onSearchChanged: (q) => setState(() => _query = q),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<_RoleViewModel> _load(String userId) async {
    final me = await _usersRepo.findById(userId);
    final allRoles = await _rolesRepo.getAll();
    final assigned = <Role>[];
    final grantedScopes = <String>{};
    if (me != null) {
      for (final id in me.roleIds) {
        for (final r in allRoles) {
          if (r.id == id) {
            assigned.add(r);
            grantedScopes.addAll(r.permissionTokens);
            break;
          }
        }
      }
    }
    return _RoleViewModel(
      assigned: assigned,
      granted: grantedScopes,
      catalog: knownPermissionScopes,
      lastSyncedAt: DateTime.now(),
    );
  }
}

class _RoleViewModel {
  const _RoleViewModel({
    required this.assigned,
    required this.granted,
    required this.catalog,
    required this.lastSyncedAt,
  });

  final List<Role> assigned;
  final Set<String> granted;
  final List<String> catalog;
  final DateTime lastSyncedAt;

  List<String> get grantedSorted {
    final list = granted.toList()..sort();
    return list;
  }

  List<String> get notGranted {
    final out = <String>[];
    for (final scope in catalog) {
      if (!granted.contains(scope)) out.add(scope);
    }
    return out;
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.vm,
    required this.searchCtrl,
    required this.query,
    required this.onSearchChanged,
  });

  final _RoleViewModel vm;
  final TextEditingController searchCtrl;
  final String query;
  final ValueChanged<String> onSearchChanged;

  bool _matchesQuery(String scope) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();
    if (scope.toLowerCase().contains(q)) return true;
    final label = humanLabelForScope(scope);
    return label.title.toLowerCase().contains(q) ||
        label.subtitle.toLowerCase().contains(q) ||
        label.module.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final granted = vm.grantedSorted.where(_matchesQuery).toList();
    final notGranted = vm.notGranted.where(_matchesQuery).toList();

    return ListView(
      padding: EdgeInsets.only(
        top: context.dynamicAppBarPadding,
        left: 16,
        right: 16,
        bottom: 40,
      ),
      children: [
        _RoleSummaryCard(vm: vm)
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.04, end: 0, duration: 350.ms),
        const SizedBox(height: 16),
        _SearchBar(
          controller: searchCtrl,
          onChanged: onSearchChanged,
        ).animate().fadeIn(delay: 60.ms),
        const SizedBox(height: 20),
        _ListSectionHeader(
          title: 'Granted',
          count: granted.length,
          accent: Colors.green,
          icon: Icons.check_circle,
        ),
        const SizedBox(height: 8),
        if (granted.isEmpty)
          _EmptyPanel(
            icon: Icons.lock_outline,
            message: query.trim().isEmpty
                ? 'No permissions granted yet.'
                : 'No granted permissions match "${query.trim()}".',
          )
        else
          _ScopeListCard(
            scopes: granted,
            isGranted: true,
          ),
        const SizedBox(height: 20),
        _ListSectionHeader(
          title: 'Not Granted',
          count: notGranted.length,
          accent: theme.colorScheme.outline,
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 8),
        if (notGranted.isEmpty)
          _EmptyPanel(
            icon: Icons.verified_outlined,
            message: query.trim().isEmpty
                ? 'You have access to every catalogued scope.'
                : 'All remaining catalogued scopes match your filter.',
          )
        else
          _ScopeListCard(
            scopes: notGranted,
            isGranted: false,
          ),
      ],
    );
  }
}

// ── Summary card ─────────────────────────────────────────────────

class _RoleSummaryCard extends StatelessWidget {
  const _RoleSummaryCard({required this.vm});
  final _RoleViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('d MMM yyyy · HH:mm');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: theme.colorScheme.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppLabel(
                  text: 'Your assigned roles',
                  fontSize: AppFontSize.value14,
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: AppLabel(
                  text:
                      '${vm.granted.length} scope${vm.granted.length == 1 ? '' : 's'}',
                  fontSize: AppFontSize.value10,
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (vm.assigned.isEmpty)
            AppLabel(
              text:
                  'No roles assigned. Ask an administrator if this looks wrong.',
              fontSize: AppFontSize.value12,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final role in vm.assigned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.onPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                        color: theme.colorScheme.onPrimary
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          role.isSystem
                              ? Icons.verified_user_rounded
                              : Icons.shield_rounded,
                          size: 14,
                          color: theme.colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 6),
                        AppLabel(
                          text: role.name,
                          fontSize: AppFontSize.value12,
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 6),
              AppLabel(
                text: 'Synced ${df.format(vm.lastSyncedAt)}',
                fontSize: AppFontSize.value12,
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Search bar ───────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search permissions…',
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              );
            },
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }
}

// ── List section header ──────────────────────────────────────────

class _ListSectionHeader extends StatelessWidget {
  const _ListSectionHeader({
    required this.title,
    required this.count,
    required this.accent,
    required this.icon,
  });

  final String title;
  final int count;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          AppLabel(
            text: title.toUpperCase(),
            fontSize: AppFontSize.value11,
            color: accent,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: AppLabel(
              text: '$count',
              fontSize: AppFontSize.value10,
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scope list card ──────────────────────────────────────────────

class _ScopeListCard extends StatelessWidget {
  const _ScopeListCard({required this.scopes, required this.isGranted});
  final List<String> scopes;
  final bool isGranted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < scopes.length; i++) ...[
            _ScopeRow(scope: scopes[i], isGranted: isGranted)
                .animate()
                .fadeIn(delay: (i * 30).clamp(0, 240).ms)
                .slideY(begin: 0.03, end: 0, duration: 250.ms),
            if (i < scopes.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({required this.scope, required this.isGranted});
  final String scope;
  final bool isGranted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = humanLabelForScope(scope);
    final accent =
        isGranted ? Colors.green.shade700 : theme.colorScheme.outline;
    final moduleAccent = _moduleAccent(theme, label.module);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_circle : Icons.lock_outline,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppLabel(
                        text: label.title,
                        fontSize: AppFontSize.value14,
                        fontWeight: FontWeight.w700,
                        color: isGranted
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                AppLabel(
                  text: label.subtitle,
                  fontSize: AppFontSize.value12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                const SizedBox(height: 4),
                AppLabel(
                  text: scope,
                  fontSize: AppFontSize.value10,
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: moduleAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: moduleAccent.withValues(alpha: 0.35),
              ),
            ),
            child: AppLabel(
              text: label.module,
              fontSize: AppFontSize.value9,
              color: moduleAccent,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Color _moduleAccent(ThemeData theme, String module) {
    switch (module.toLowerCase()) {
      case 'finance':
        return Colors.indigo;
      case 'inventory':
        return Colors.orange.shade700;
      case 'sales':
        return Colors.green.shade700;
      case 'hr':
        return Colors.purple;
      case 'projects':
        return Colors.blue;
      case 'procurement':
        return Colors.teal;
      case 'admin':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.outline;
    }
  }
}

// ── Empty panel ──────────────────────────────────────────────────

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: AppLabel(
              text: message,
              fontSize: AppFontSize.value14,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
