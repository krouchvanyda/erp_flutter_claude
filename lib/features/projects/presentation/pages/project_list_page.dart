import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../domain/entities/project.dart';
import '../../domain/usecases/compute_gantt_layout.dart';
import '../bloc/project_list_bloc.dart';
import '../bloc/project_list_event.dart';
import '../bloc/project_list_state.dart';
import '../widgets/gantt_chart.dart';

/// Slice 8.1.1 — project list with toggleable Gantt timeline.
class ProjectListPage extends StatelessWidget {
  const ProjectListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProjectListBloc>(
      create: (_) =>
          GetIt.I<ProjectListBloc>()..add(const ProjectListStarted()),
      child: const _ProjectListView(),
    );
  }
}

enum _Mode { list, gantt }

class _ProjectListView extends StatefulWidget {
  const _ProjectListView();

  @override
  State<_ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState extends State<_ProjectListView> {
  _Mode _mode = _Mode.list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: 'Projects',
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Timesheets',
            icon: const Icon(Icons.schedule),
            onPressed: () =>
                context.pushNamed(RoutePaths.timesheetsName),
          ),
          PopupMenuButton<ProjectSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            onSelected: (s) => context
                .read<ProjectListBloc>()
                .add(ProjectListSortChanged(s)),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: ProjectSort.nameAsc,
                child: Text('Name (A–Z)'),
              ),
              PopupMenuItem(
                value: ProjectSort.recentlyStarted,
                child: Text('Recently started'),
              ),
              PopupMenuItem(
                value: ProjectSort.dueSoonest,
                child: Text('Due soonest'),
              ),
            ],
          ),
        ],
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            // Premium background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                    theme.colorScheme.surface,
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
            BlocBuilder<ProjectListBloc, ProjectListState>(
              builder: (context, state) {
                if (state.isLoading && state.source.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.errorMessage != null) {
                  return Center(
                    child: Text(
                      'Error: ${state.errorMessage}',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  );
                }
                return Column(
                  children: [
                    SizedBox(height: context.dynamicAppBarPadding),
                    // Search & View Mode Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                        child: Column(
                          children: [
                            SegmentedButton<_Mode>(
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: _Mode.list,
                                  icon: Icon(Icons.list_rounded),
                                  label: Text('List View'),
                                ),
                                ButtonSegment(
                                  value: _Mode.gantt,
                                  icon: Icon(Icons.analytics_outlined),
                                  label: Text('Gantt Chart'),
                                ),
                              ],
                              selected: {_mode},
                              onSelectionChanged: (s) =>
                                  setState(() => _mode = s.first),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              onChanged: (q) => context
                                  .read<ProjectListBloc>()
                                  .add(ProjectListSearchChanged(q)),
                              decoration: InputDecoration(
                                hintText: 'Search name, code, owner…',
                                prefixIcon: const Icon(Icons.search_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadii.md),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadii.md),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                ),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn().slideY(begin: -0.05, end: 0, duration: 250.ms),
                    ),
                    const SizedBox(height: 12),
                    // Status Filter Chips
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: ProjectStatus.values.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, idx) {
                          final s = ProjectStatus.values[idx];
                          final isSelected = state.statusFilter.contains(s);
                          return FilterChip(
                            label: Text(s.name.toUpperCase()),
                            labelStyle: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                            selected: isSelected,
                            onSelected: (_) => context
                                .read<ProjectListBloc>()
                                .add(ProjectListStatusToggled(s)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                          );
                        },
                      ),
                    ).animate().fadeIn(delay: 50.ms),
                    const SizedBox(height: 12),
                    if (state.visible.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'No projects match.',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: _mode == _Mode.list
                            ? _buildList(state.visible)
                            : _buildGantt(state.visible),
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

  Widget _buildList(List<Project> projects) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: projects.length,
      itemBuilder: (_, idx) => _ProjectRow(project: projects[idx])
          .animate()
          .fadeIn(delay: (idx * 50).ms)
          .slideY(begin: 0.05, end: 0, duration: 300.ms),
    );
  }

  Widget _buildGantt(List<Project> projects) {
    final now = DateTime.now();
    final windowStart = DateTime.utc(now.year, now.month, 1)
        .subtract(const Duration(days: 30));
    final windowEnd = windowStart.add(const Duration(days: 180));
    final rows = computeGanttLayout(
      projects: projects,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    return GanttChart(
      rows: rows,
      windowStart: windowStart,
      windowEnd: windowEnd,
      onTap: (project) => context.pushNamed(
        RoutePaths.projectDetailName,
        pathParameters: {RoutePaths.projectDetailIdParam: project.id},
      ),
    ).animate().fadeIn();
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(project.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.pushNamed(
              RoutePaths.projectDetailName,
              pathParameters: {RoutePaths.projectDetailIdParam: project.id},
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          color: _projectColor(project.color).withValues(alpha: 0.1),
                          border: Border.all(
                            color: _projectColor(project.color).withValues(alpha: 0.3),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          project.code.split('-').first.substring(
                              0, project.code.split('-').first.length.clamp(0, 3)),
                          style: TextStyle(
                            color: _projectColor(project.color),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Code: ${project.code} • Owner: ${project.ownerName}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          project.status.name.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 0.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${project.startDate.toIso8601String().split('T').first} to ${project.endDate.toIso8601String().split('T').first}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${project.totalDays} Days',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _projectColor(String? hex) {
    if (hex == null || hex.length != 6) return Colors.indigo;
    return Color(int.parse('FF$hex', radix: 16));
  }

  Color _statusColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planning:
        return Colors.blue;
      case ProjectStatus.active:
        return Colors.green;
      case ProjectStatus.onHold:
        return Colors.orange;
      case ProjectStatus.completed:
        return Colors.teal;
      case ProjectStatus.archived:
        return Colors.grey;
    }
  }
}
