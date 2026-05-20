import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../../../shared/widgets/app_background_gradient.dart';
import '../../entities/employee.dart';
import '../bloc/employee_list_bloc.dart';
import '../bloc/employee_list_event.dart';
import '../bloc/employee_list_state.dart';

/// Slice 7.1.1 — directory list with search + department filter chips.
///
/// Provides the bloc inline (not via outer-scope provider) so the page
/// is self-contained and the bloc disposes when the route pops.
class EmployeeListPage extends StatelessWidget {
  const EmployeeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EmployeeListBloc>(
      create: (_) =>
          GetIt.I<EmployeeListBloc>()..add(const EmployeeListStarted()),
      child: const _EmployeeListView(),
    );
  }
}

class _EmployeeListView extends StatelessWidget {
  const _EmployeeListView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: 'Employee Directory',
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Org chart',
            icon: const Icon(Icons.account_tree_rounded),
            onPressed: () => context.pushNamed(RoutePaths.hrOrgChartName),
          ),
          PopupMenuButton<EmployeeSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            onSelected: (s) => context
                .read<EmployeeListBloc>()
                .add(EmployeeListSortChanged(s)),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: EmployeeSort.nameAsc,
                child: Text('Name (A–Z)'),
              ),
              PopupMenuItem(
                value: EmployeeSort.recentlyHired,
                child: Text('Recently hired'),
              ),
              PopupMenuItem(
                value: EmployeeSort.departmentAsc,
                child: Text('Department'),
              ),
            ],
          ),
        ],
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            const AppBackgroundGradient(),
            BlocBuilder<EmployeeListBloc, EmployeeListState>(
              builder: (context, state) {
                if (state.isLoading && state.source.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.errorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 60,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading directory',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    SizedBox(height: context.dynamicAppBarPadding - 10),
                    // Search & Filters Header Container
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (q) => context
                                .read<EmployeeListBloc>()
                                .add(EmployeeListSearchChanged(q)),
                            decoration: InputDecoration(
                              hintText: 'Search name, email, position…',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: theme.colorScheme.surface.withValues(alpha: 0.8),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
                          if (state.departments.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 38,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: state.departments.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, idx) {
                                  final dept = state.departments[idx];
                                  final isSelected = state.departmentFilter.contains(dept);
                                  return FilterChip(
                                    label: Text(dept),
                                    selected: isSelected,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadii.pill),
                                    ),
                                    labelStyle: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurface,
                                    ),
                                    selectedColor: theme.colorScheme.primaryContainer,
                                    onSelected: (_) => context
                                        .read<EmployeeListBloc>()
                                        .add(EmployeeListDepartmentToggled(dept)),
                                  );
                                },
                              ),
                            ).animate().fadeIn(duration: 450.ms),
                          ],
                        ],
                      ),
                    ),
                    if (state.visible.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.people_outline_rounded,
                                  size: 64,
                                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No matching employees',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try refining your search query or filters',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ).animate().fadeIn(),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: state.visible.length,
                          itemBuilder: (context, idx) {
                            final employee = state.visible[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _EmployeeCard(employee: employee)
                                  .animate()
                                  .fadeIn(delay: (idx * 30).ms)
                                  .slideY(begin: 0.05, end: 0, duration: 300.ms),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme, employee.status);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          RoutePaths.hrEmployeeDetailName,
          pathParameters: {RoutePaths.hrEmployeeDetailIdParam: employee.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                backgroundImage: employee.avatarUrl != null
                    ? NetworkImage(employee.avatarUrl!)
                    : null,
                child: employee.avatarUrl == null
                    ? Text(
                        employee.name.isEmpty ? '?' : employee.name[0],
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee.position,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee.department,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: employee.status, color: statusColor),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ThemeData theme, EmploymentStatus s) {
    return switch (s) {
      EmploymentStatus.active => theme.colorScheme.primary,
      EmploymentStatus.onLeave => theme.colorScheme.secondary,
      EmploymentStatus.suspended => theme.colorScheme.error,
      EmploymentStatus.terminated => theme.colorScheme.outline,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});
  final EmploymentStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = switch (status) {
      EmploymentStatus.active => 'ACTIVE',
      EmploymentStatus.onLeave => 'ON LEAVE',
      EmploymentStatus.suspended => 'SUSPENDED',
      EmploymentStatus.terminated => 'TERMINATED',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 8.5,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
