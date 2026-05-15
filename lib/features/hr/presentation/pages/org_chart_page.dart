import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/employee.dart';
import '../../domain/repositories/employees_repository.dart';
import '../../domain/usecases/build_org_chart.dart';

/// Slice 7.1.3 — indented tree view of the manager hierarchy.
///
/// Renders the flattened forest as a `ListView.builder` rather than a
/// recursive widget so deep org structures don't blow the build stack
/// and so each row gets the standard list virtualisation.
class OrgChartPage extends StatelessWidget {
  const OrgChartPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organization Chart')),
      body: FutureBuilder<List<Employee>>(
        future: GetIt.I<EmployeesRepository>().getAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final employees = snapshot.data ?? const <Employee>[];
          if (employees.isEmpty) {
            return const Center(child: Text('No employees yet.'));
          }
          final flat = flattenOrgChart(buildOrgChart(employees));
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: flat.length,
            itemBuilder: (context, idx) {
              final node = flat[idx];
              return Padding(
                padding: EdgeInsets.only(left: 12.0 + 20.0 * node.depth),
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueGrey.shade100,
                      child: Text(
                        node.employee.name.isEmpty
                            ? '?'
                            : node.employee.name[0],
                      ),
                    ),
                    title: Text(node.employee.name),
                    subtitle: Text(
                      '${node.employee.position} • ${node.employee.department}',
                    ),
                    trailing: node.reports.isNotEmpty
                        ? Tooltip(
                            message: '${node.reports.length} direct reports',
                            child: Badge(
                              label: Text('${node.reports.length}'),
                              child: const Icon(Icons.people_alt_outlined),
                            ),
                          )
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
