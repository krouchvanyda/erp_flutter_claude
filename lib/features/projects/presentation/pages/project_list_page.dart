import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../domain/entities/project.dart';
import '../../domain/usecases/compute_gantt_layout.dart';
import '../bloc/project_list_bloc.dart';
import '../bloc/project_list_event.dart';
import '../bloc/project_list_state.dart';
import '../widgets/gantt_chart.dart';

/// Slice 8.1.1 — project list with toggleable Gantt timeline.
///
/// Two views:
/// - **List**: searchable + sortable card list (default).
/// - **Gantt**: custom-painter timeline scoped to the next 6 months;
///   built from the same filtered dataset as the list so the user can
///   filter once and see both views consistently.
class ProjectListPage extends StatelessWidget {
  const ProjectListPage();

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
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
      body: BlocBuilder<ProjectListBloc, ProjectListState>(
        builder: (context, state) {
          if (state.isLoading && state.source.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null) {
            return Center(child: Text('Error: ${state.errorMessage}'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SegmentedButton<_Mode>(
                      segments: const [
                        ButtonSegment(
                          value: _Mode.list,
                          icon: Icon(Icons.list),
                          label: Text('List'),
                        ),
                        ButtonSegment(
                          value: _Mode.gantt,
                          icon: Icon(Icons.bar_chart),
                          label: Text('Timeline'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) =>
                          setState(() => _mode = s.first),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (q) => context
                          .read<ProjectListBloc>()
                          .add(ProjectListSearchChanged(q)),
                      decoration: InputDecoration(
                        hintText: 'Search name, code, owner…',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: ProjectStatus.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, idx) {
                    final s = ProjectStatus.values[idx];
                    return FilterChip(
                      label: Text(s.name),
                      selected: state.statusFilter.contains(s),
                      onSelected: (_) => context
                          .read<ProjectListBloc>()
                          .add(ProjectListStatusToggled(s)),
                    );
                  },
                ),
              ),
              if (state.visible.isEmpty)
                const Expanded(
                  child: Center(child: Text('No projects match.')),
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
    );
  }

  Widget _buildList(List<Project> projects) {
    return ListView.separated(
      itemCount: projects.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, idx) => _ProjectRow(project: projects[idx]),
    );
  }

  Widget _buildGantt(List<Project> projects) {
    // 6-month window centred on the start of this month so the
    // active projects are always visible without horizontal scroll.
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
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: _projectColor(project.color),
        ),
        alignment: Alignment.center,
        child: Text(
          project.code.split('-').first.substring(
              0, project.code.split('-').first.length.clamp(0, 3)),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(project.name),
      subtitle: Text(
        '${project.code} • ${project.ownerName} • '
        '${project.startDate.toIso8601String().split('T').first} → '
        '${project.endDate.toIso8601String().split('T').first}',
      ),
      trailing: Chip(
        label: Text(project.status.name),
        backgroundColor: _statusColor(project.status),
        visualDensity: VisualDensity.compact,
      ),
      onTap: () => context.pushNamed(
        RoutePaths.projectDetailName,
        pathParameters: {RoutePaths.projectDetailIdParam: project.id},
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
        return Colors.blue.shade100;
      case ProjectStatus.active:
        return Colors.green.shade100;
      case ProjectStatus.onHold:
        return Colors.orange.shade100;
      case ProjectStatus.completed:
        return Colors.grey.shade300;
      case ProjectStatus.archived:
        return Colors.grey.shade200;
    }
  }
}
