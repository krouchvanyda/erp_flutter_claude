import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/security/app_permissions.dart';
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
import '../../data/models/page_response.dart';
import '../../data/models/role_dto.dart';
import '../../data/models/user_dto.dart';
import '../../data/models/user_requests.dart';

/// Admin-only **Assign Roles** page.
///
/// One flow: pick a user → pick a role → save. PATCHes the user with
/// `{"roles": ["<role-code>"]}` — backend's `UpdateUserRequest` takes
/// `Set<String> roles` of role codes and replaces the user's full
/// role set. Sending `null` would leave roles untouched; an empty list
/// strips every role.
///
/// **Permission gating** — only super-admins reach the editor. Non-
/// super-admins see [_SuperAdminLock] instead. Backend would 403
/// anyway; the client gate avoids the round-trip and shows a clearer
/// message.
///
/// One bundle load (`/users/me` + `/roles` + first page of `/users`)
/// on mount; save success re-fires it.
class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  final _users = GetIt.I<UsersRemoteDataSource>();
  final _roles = GetIt.I<RolesRemoteDataSource>();

  late Future<_AssignmentsBundle> _bundleFuture = _load();

  void _reload() {
    setState(() => _bundleFuture = _load());
  }

  /// Fan out three GETs in parallel — none depend on each other.
  Future<_AssignmentsBundle> _load() async {
    final results = await Future.wait<dynamic>([
      _users.me(),
      _roles.listRoles(),
      _users.listUsers(page: 1, pageSize: 50),
    ]);
    return _AssignmentsBundle(
      me: results[0] as UserDto,
      roles: results[1] as List<RoleDto>,
      usersPage: results[2] as PageResponse<UserDto>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: l10n.assignmentsPageTitle,
        centerTitle: true,
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            const AppBackgroundGradient(),
            FutureBuilder<_AssignmentsBundle>(
              future: _bundleFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: LoadingScreen());
                }
                if (snap.hasError || !snap.hasData) {
                  return _ErrorPanel(onRetry: _reload);
                }
                final bundle = snap.data!;
                // Debug breadcrumb so we can see exactly what `/users/me`
                // returned when the gate denies a user who *should* be
                // a super-admin. Remove once the RBAC wiring is stable.
                developer.log(
                  '[Assignments] me.id=${bundle.me.id} '
                  'roles=${bundle.me.roles} canEdit=${bundle.canEdit}',
                  name: 'Assignments',
                );
                // Whole-page super-admin gate. Non-super-admins get a
                // full-screen lock — backend would 403 anyway, this is
                // the friendlier UX.
                if (!bundle.canEdit) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: context.dynamicAppBarPadding,
                    ),
                    child: const _SuperAdminLock(),
                  );
                }
                return Padding(
                  padding: EdgeInsets.only(
                    top: context.dynamicAppBarPadding,
                  ),
                  child: _UsersToRolesForm(
                    bundle: bundle,
                    usersApi: _users,
                    onSaved: _reload,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Bundle of everything the form needs. Fetched once on mount + on
/// every save success.
class _AssignmentsBundle {
  const _AssignmentsBundle({
    required this.me,
    required this.roles,
    required this.usersPage,
  });

  final UserDto me;
  final List<RoleDto> roles;
  final PageResponse<UserDto> usersPage;

  /// Whole-page gate: assigning roles is super-admin only by policy.
  /// Regular admins / staff can browse `My roles & permissions` but
  /// never reach this page's editor.
  bool get canEdit => isSuperAdmin(me.roles);
}

// ════════════════════════════════════════════════════════════════════
// Users → Roles form (the only flow on this page)
// ════════════════════════════════════════════════════════════════════

class _UsersToRolesForm extends StatefulWidget {
  const _UsersToRolesForm({
    required this.bundle,
    required this.usersApi,
    required this.onSaved,
  });

  final _AssignmentsBundle bundle;
  final UsersRemoteDataSource usersApi;
  final VoidCallback onSaved;

  @override
  State<_UsersToRolesForm> createState() => _UsersToRolesFormState();
}

class _UsersToRolesFormState extends State<_UsersToRolesForm> {
  UserDto? _selected;

  /// Drafted role for the currently-selected user. Single-select model:
  /// the backend allows N roles per user but the UX assigns exactly one
  /// at a time (matches the V3 seed convention + the team's SQL
  /// `UPDATE user_roles SET role_id = X` flow). Save sends a
  /// single-element list, which the backend treats as "replace all
  /// assigned roles with this one".
  RoleDto? _draftRole;
  bool _saving = false;

  void _selectUser(UserDto user) {
    setState(() {
      _selected = user;
      // Resolve the user's *first* current role (if any) into a RoleDto
      // so the dropdown shows it pre-selected. Falls through to null
      // when the user has no role yet.
      _draftRole = _resolveFirstRole(user.roles, widget.bundle.roles);
    });
  }

  void _selectRole(RoleDto? role) {
    setState(() => _draftRole = role);
  }

  /// `user.roles` from the wire could be ids, codes (`SUPER_ADMIN`),
  /// or display names (`Super Admin`) depending on which endpoint
  /// shipped the user — match any of them against the full role list
  /// so the dropdown's pre-selected value lines up regardless of shape.
  static RoleDto? _resolveFirstRole(
    Iterable<String> identifiers,
    List<RoleDto> all,
  ) {
    for (final identifier in identifiers) {
      final needle = identifier.trim().toLowerCase();
      if (needle.isEmpty) continue;
      for (final r in all) {
        if (r.id == identifier ||
            r.code.toLowerCase() == needle ||
            r.name.toLowerCase() == needle) {
          return r;
        }
      }
    }
    return null;
  }

  bool get _isDirty {
    final user = _selected;
    if (user == null) return false;
    final originalRole = _resolveFirstRole(user.roles, widget.bundle.roles);
    return originalRole?.id != _draftRole?.id;
  }

  Future<void> _save() async {
    final user = _selected;
    if (user == null || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      // Send the picked role's **code** (e.g. `"STAFF"`) under the
      // **`roles`** JSON key — that's what the Spring DTO actually
      // expects:
      //
      //   public record UpdateUserRequest(..., Set<String> roles) {}
      //
      // Earlier iterations sent `roleIds: [3]` / `roleIds: ["3"]` /
      // `roles: [3]` — Jackson silently dropped every one because the
      // shapes didn't match the record's field name + type. Result:
      // `"roles": []` on the response. Codes-as-strings is the only
      // shape that actually persists.
      //
      // Empty list = strip every role; null (default ctor arg) = leave
      // roles untouched.
      final roles = _draftRole != null
          ? <String>[_draftRole!.code]
          : const <String>[];
      final body = UpdateUserRequest(roles: roles);
      developer.log(
        '[Assignments] PATCH /users/${user.id} '
        'body=${body.toJson()}',
        name: 'Assignments',
      );
      await widget.usersApi.updateUser(user.id, body);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.assignmentsSavedSnack),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onSaved();
    } catch (e, stack) {
      // Surface the real reason. The previous `catch (_)` silently
      // swallowed the cause, so a 403 from a missing permission, a 400
      // from a malformed body, or a connection refused all looked
      // identical to the user.
      developer.log(
        '[Assignments] PATCH /users/${user.id} FAILED: $e',
        name: 'Assignments',
        error: e,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${l10n.assignmentsSaveFailedSnack}: ${_humanError(e)}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
          // Long error messages need room to be readable.
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Copy',
            textColor: Colors.white,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: e.toString()));
            },
          ),
        ),
      );
    }
  }

  /// Strip the noisy dio prefix so the snackbar shows the actionable
  /// part — HTTP status + server message — instead of the full
  /// "DioException [bad response]: …" wrapper. Falls back to the raw
  /// `toString()` for non-dio errors.
  String _humanError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      // Spring envelope ships failures as
      // `{success: false, message: "...", errorCode: "..."}`.
      if (data is Map && data['message'] is String) {
        final msg = data['message'] as String;
        return status != null ? 'HTTP $status — $msg' : msg;
      }
      if (status != null) {
        return 'HTTP $status — ${e.message ?? e.type.name}';
      }
      return e.message ?? e.type.name;
    }
    return e.toString();
  }

  Future<void> _openUserPicker() async {
    if (_saving) return;
    final picked = await showModalBottomSheet<UserDto>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UserPickerSheet(
        users: widget.bundle.usersPage.items,
        initialSelectedId: _selected?.id,
      ),
    );
    if (picked != null) {
      _selectUser(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final canEdit = widget.bundle.canEdit;
    final hasUser = _selected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Subtitle that anchors the flow: one user, one role.
                AppLabel(
                  text: l10n.assignmentsAssignSubtitle,
                  fontSize: AppFontSize.value13,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                const SizedBox(height: 20),
                // ── USER section ────────────────────────────────────
                _FieldLabel(text: l10n.assignmentsUserFieldLabel),
                const SizedBox(height: 6),
                _UserPickerField(
                  user: _selected,
                  enabled: canEdit,
                  onTap: _openUserPicker,
                ),
                const SizedBox(height: 20),
                // ── ROLE section ────────────────────────────────────
                _FieldLabel(
                  text: l10n.assignmentsRoleFieldLabel,
                  // Dim the label when the dropdown is disabled — makes
                  // it obvious the section isn't yet active.
                  dim: !hasUser,
                ),
                const SizedBox(height: 6),
                _AssignRoleDropdown(
                  roles: widget.bundle.roles,
                  value: _draftRole,
                  // Role dropdown only becomes interactive once a user
                  // is picked — assigning a role to nobody makes no
                  // sense and would confuse the dirty-check.
                  enabled: canEdit && hasUser && !_saving,
                  onChanged: _selectRole,
                ),
                const SizedBox(height: 8),
                // Helper text shifts based on state so the user always
                // knows why the role field is or isn't actionable.
                AppLabel(
                  text: hasUser
                      ? l10n.assignmentsRoleHelperCurrentRole
                      : l10n.assignmentsRoleHelperPickUserFirst,
                  fontSize: AppFontSize.value12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ],
            ),
          ),
        ),
        // Hairline divider visually separates the sticky save bar from
        // the scrollable form above.
        Divider(
          height: 1,
          thickness: 0.5,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _SaveBar(
              enabled: canEdit && hasUser && _isDirty && !_saving,
              saving: _saving,
              dirtyLabel: l10n.assignmentsSaveAction,
              cleanLabel: l10n.assignmentsNoChangesYet,
              onSave: _save,
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Form pieces — labels, pickers, save bar
// ════════════════════════════════════════════════════════════════════

/// Small uppercase label that sits above each picker ("USER", "ROLE").
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, this.dim = false});

  final String text;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AppLabel(
        text: text.toUpperCase(),
        fontSize: AppFontSize.value11,
        color: dim
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.primary,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isSelected,
    required this.onTap,
  });

  final UserDto user;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = user.fullName.trim().isEmpty
        ? '?'
        : user.fullName.trim()[0].toUpperCase();
    return ListTile(
      onTap: onTap,
      selected: isSelected,
      selectedTileColor:
          theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      leading: CircleAvatar(
        backgroundColor: user.enabled
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest,
        child: AppLabel(
          text: initials,
          fontSize: AppFontSize.value14,
          fontWeight: FontWeight.w900,
          color: user.enabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: AppLabel(
        text: user.fullName.trim().isEmpty ? user.email : user.fullName,
        fontSize: AppFontSize.value14,
        fontWeight: FontWeight.w700,
      ),
      subtitle: AppLabel(
        text: user.email,
        fontSize: AppFontSize.value12,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20)
          : null,
    );
  }
}

/// Tap-to-pick "Select user" field. Renders a form-field-styled row —
/// avatar + name + email when a user is selected, hint text otherwise.
/// Tapping opens [_UserPickerSheet] where the actual list lives.
class _UserPickerField extends StatelessWidget {
  const _UserPickerField({
    required this.user,
    required this.enabled,
    required this.onTap,
  });

  final UserDto? user;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasUser = user != null;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_outline,
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: hasUser
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppLabel(
                          text: user!.fullName.trim().isEmpty
                              ? user!.email
                              : user!.fullName,
                          fontSize: AppFontSize.value14,
                          fontWeight: FontWeight.w700,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user!.fullName.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          AppLabel(
                            text: user!.email,
                            fontSize: AppFontSize.value12,
                            color: theme.colorScheme.onSurfaceVariant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    )
                  : AppLabel(
                      text: l10n.assignmentsPickUserPrompt,
                      fontSize: AppFontSize.value14,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet with a searchable list of users. Tapping a row
/// pops the sheet with the picked [UserDto]. Search filters by full
/// name + email.
class _UserPickerSheet extends StatefulWidget {
  const _UserPickerSheet({
    required this.users,
    required this.initialSelectedId,
  });

  final List<UserDto> users;
  final String? initialSelectedId;

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  String _query = '';

  List<UserDto> get _filtered {
    if (_query.trim().isEmpty) return widget.users;
    final q = _query.trim().toLowerCase();
    return widget.users
        .where((u) =>
            u.fullName.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final users = _filtered;

    // Take up to ~75% of the screen so the keyboard + sheet fit
    // comfortably and the list can scroll within the remaining space.
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                onChanged: (q) => setState(() => _query = q),
                decoration: InputDecoration(
                  hintText: l10n.assignmentsUsersSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: users.isEmpty
                    ? _EmptyHint(
                        icon: Icons.person_outline,
                        message: l10n.assignmentsEmptyUsers,
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: users.length,
                        padding: EdgeInsets.zero,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (_, i) {
                          final u = users[i];
                          return _UserRow(
                            user: u,
                            isSelected: u.id == widget.initialSelectedId,
                            onTap: () => Navigator.of(context).pop(u),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single-select role dropdown. `isExpanded: true` so the trigger
/// fills the parent column; ellipsis on long names; SYSTEM badge for
/// built-in roles.
class _AssignRoleDropdown extends StatelessWidget {
  const _AssignRoleDropdown({
    required this.roles,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<RoleDto> roles;
  final RoleDto? value;
  final bool enabled;
  final ValueChanged<RoleDto?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<RoleDto>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.assignmentsRolePickerLabel,
        prefixIcon: const Icon(Icons.shield_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
      ),
      hint: AppLabel(
        text: l10n.assignmentsPickRolePrompt,
        fontSize: AppFontSize.value14,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      items: [
        for (final r in roles)
          DropdownMenuItem<RoleDto>(
            value: r,
            child: Row(
              children: [
                Icon(
                  r.isSystem
                      ? Icons.verified_user_rounded
                      : Icons.shield_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: AppLabel(
                    text: r.name,
                    fontSize: AppFontSize.value14,
                    fontWeight: FontWeight.w700,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (r.isSystem) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: AppLabel(
                      text: l10n.assignmentsSystemRoleBadge,
                      fontSize: AppFontSize.value9,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.enabled,
    required this.saving,
    required this.dirtyLabel,
    required this.cleanLabel,
    required this.onSave,
  });

  final bool enabled;
  final bool saving;
  final String dirtyLabel;
  final String cleanLabel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: enabled ? onSave : null,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
        child: saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : AppLabel(
                text: enabled ? dirtyLabel : cleanLabel,
                fontSize: AppFontSize.value14,
                fontWeight: FontWeight.bold,
              ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Empty / error / lock panels
// ════════════════════════════════════════════════════════════════════

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            AppLabel(
              text: message,
              fontSize: AppFontSize.value13,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-page lock shown when the current user isn't a super-admin.
///
/// Matches the policy "only super admin can assign roles".
class _SuperAdminLock extends StatelessWidget {
  const _SuperAdminLock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 56,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),
            AppLabel(
              text: l10n.assignmentsSuperAdminOnlyTitle,
              fontSize: AppFontSize.value18,
              fontWeight: FontWeight.w900,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppLabel(
              text: l10n.assignmentsSuperAdminOnlyMessage,
              fontSize: AppFontSize.value14,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              textAlign: TextAlign.center,
              lineHeight: 1.4,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

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
