import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../domain/entities/employee.dart';
import '../bloc/employee_list_bloc.dart';
import '../bloc/employee_list_event.dart';
import '../bloc/employee_list_state.dart';

/// Slice 7.1.1 — directory list with search + department filter chips.
///
/// Provides the bloc inline (not via outer-scope provider) so the page
/// is self-contained and the bloc disposes when the route pops.
class EmployeeListPage extends StatelessWidget {
  const EmployeeListPage();

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Directory'),
        actions: [
          IconButton(
            tooltip: 'Org chart',
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: () => context.pushNamed(RoutePaths.hrOrgChartName),
          ),
          PopupMenuButton<EmployeeSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
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
      body: BlocBuilder<EmployeeListBloc, EmployeeListState>(
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
                child: TextField(
                  onChanged: (q) => context
                      .read<EmployeeListBloc>()
                      .add(EmployeeListSearchChanged(q)),
                  decoration: InputDecoration(
                    hintText: 'Search name, email, position…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              if (state.departments.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: state.departments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, idx) {
                      final dept = state.departments[idx];
                      return FilterChip(
                        label: Text(dept),
                        selected: state.departmentFilter.contains(dept),
                        onSelected: (_) => context
                            .read<EmployeeListBloc>()
                            .add(EmployeeListDepartmentToggled(dept)),
                      );
                    },
                  ),
                ),
              if (state.visible.isEmpty)
                const Expanded(
                  child: Center(child: Text('No employees match.')),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: state.visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) =>
                        _EmployeeRow(employee: state.visible[idx]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blueGrey.shade100,
        child: Text(employee.name.isEmpty ? '?' : employee.name[0]),
      ),
      title: Text(employee.name),
      subtitle: Text('${employee.department} • ${employee.position}'),
      trailing: Chip(
        label: Text(employee.status.name),
        backgroundColor: employee.status == EmploymentStatus.active
            ? Colors.green.shade100
            : Colors.orange.shade100,
        visualDensity: VisualDensity.compact,
      ),
      onTap: () => context.pushNamed(
        RoutePaths.hrEmployeeDetailName,
        pathParameters: {RoutePaths.hrEmployeeDetailIdParam: employee.id},
      ),
    );
  }
}
