import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_font_size.dart';
import '../../../../core/theme/app_label.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_background_gradient.dart';
import '../../data/datasources/roles_remote_data_source.dart';
import '../../data/datasources/users_remote_data_source.dart';
import '../../data/models/role_dto.dart';
import '../../data/models/user_dto.dart';
import '../../data/permission_catalog.dart';
import '../../entities/managed_user.dart';

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
  final _usersRemote = GetIt.I<UsersRemoteDataSource>();
  final _rolesRemote = GetIt.I<RolesRemoteDataSource>();

  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Held in state (vs created inline in `build`) so a `setState` from
  /// the search field doesn't re-fire the network calls. Reassigned only
  /// when the user pulls to refresh or hits Retry.
  late Future<_RoleViewModel> _loadFuture = _load();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _loadFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: l10n.myRolesPageTitle,
        centerTitle: true,
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            const AppBackgroundGradient(),
            FutureBuilder<_RoleViewModel>(
              future: _loadFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: LoadingScreen());
                }
                if (snap.hasError || !snap.hasData) {
                  return _ErrorPanel(onRetry: _reload);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    // Wait on the new future so the indicator stays
                    // visible until the call actually finishes.
                    await _loadFuture;
                  },
                  child: _Body(
                    vm: snap.data!,
                    searchCtrl: _searchCtrl,
                    query: _query,
                    onSearchChanged: (q) => setState(() => _query = q),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Fan out three GETs in parallel — they don't depend on each other,
  /// so `Future.wait` cuts perceived latency by ~2/3 vs sequential.
  ///
  /// - `GET /users/me`              → current user with already-resolved
  ///                                  permissions (no need to walk roles)
  /// - `GET /roles`                 → role definitions for the chip
  ///                                  summary (name + isSystem flag)
  /// - `GET /roles/permissions`     → full catalog used for the
  ///                                  "Not granted" comparison list
  Future<_RoleViewModel> _load() async {
    final results = await Future.wait<dynamic>([
      _usersRemote.me(),
      _rolesRemote.listRoles(),
      _rolesRemote.listPermissions(),
    ]);
    final me = results[0] as UserDto;
    final allRoles = results[1] as List<RoleDto>;
    final allPermissions = results[2] as List<PermissionDto>;

    // Match each role id/name from `/me` against the full role list
    // for chip rendering. `me.roles` arrives as identifiers (per the
    // V3 seed, the values look like `"SUPER_ADMIN"` — i.e. role
    // codes, not numeric ids). Match by both id and name so either
    // wire shape works without code change.
    final assigned = <Role>[];
    for (final identifier in me.roles) {
      final match = _findRole(allRoles, identifier);
      assigned.add(
        match != null
            ? Role(
                id: match.id,
                name: match.name,
                description: match.description,
                permissionTokens: match.permissionTokens,
                isSystem: match.isSystem,
              )
            : Role(
                // Fallback chip — backend hasn't shipped the role
                // definition yet (or we got an unknown id). Render the
                // identifier verbatim so the user still sees *something*.
                id: identifier,
                name: identifier,
                description: '',
                permissionTokens: const <String>[],
              ),
      );
    }

    // `me.permissions` already contains the union of every grant from
    // every assigned role — server-side resolution, no client math.
    final grantedScopes = me.permissions.toSet();

    // Catalog drives the "Not granted" list. Prefer the live backend
    // catalog so newly-added scopes appear without an app release;
    // fall back to the bundled `knownPermissionScopes` when the
    // catalog endpoint returns empty (e.g. dev seed not run).
    final catalog = allPermissions.isNotEmpty
        ? allPermissions.map((p) => p.token).toList(growable: false)
        : knownPermissionScopes;

    return _RoleViewModel(
      assigned: assigned,
      granted: grantedScopes,
      catalog: catalog,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Matches a role identifier from `/me` (which may be an id or a
  /// human-readable code like `"SUPER_ADMIN"`) against the full
  /// `/roles` list. Case-insensitive name match because the backend
  /// could ship `SUPER_ADMIN` or `Super_Admin` depending on seed-data
  /// conventions and we don't want a casing change to break chips.
  static RoleDto? _findRole(List<RoleDto> all, String identifier) {
    for (final r in all) {
      if (r.id == identifier) return r;
      if (r.name.toLowerCase() == identifier.toLowerCase()) return r;
    }
    return null;
  }
}

/// Failure panel — shown when any of the three GETs throws. Generic
/// retry rather than per-error UX since the page is read-only.
class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            AppLabel(
              text: l10n.commonLoadFailedFallback,
              fontSize: AppFontSize.value14,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: AppLabel(
                text: l10n.commonRetryAction,
                fontSize: AppFontSize.value14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
    final l10n = AppLocalizations.of(context);
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
          title: l10n.myRolesGrantedTitle,
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
    final l10n = AppLocalizations.of(context);
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
                  text: l10n.myRolesAssignedRolesLabel,
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
                text: l10n.myRolesSyncedAtLabel(df.format(vm.lastSyncedAt)),
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
          hintText: AppLocalizations.of(context).myRolesSearchHint,
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
