import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employees_repository.dart';

/// Slice 7.1.2 — employee profile detail.
class EmployeeDetailPage extends StatelessWidget {
  const EmployeeDetailPage({required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee')),
      body: FutureBuilder<Employee?>(
        future: GetIt.I<EmployeesRepository>().findById(employeeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final emp = snapshot.data;
          if (emp == null) {
            return Center(
              child: Text('No employee with id "$employeeId".'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(employee: emp),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Email', emp.email),
                      _row('Phone', emp.phone),
                      _row('Department', emp.department),
                      _row('Position', emp.position),
                      _row('Location', emp.location ?? '—'),
                      _row(
                        'Hired',
                        emp.hiredAt.toIso8601String().split('T').first,
                      ),
                      _row('Status', emp.status.name),
                      _row('Monthly salary', emp.monthlySalary),
                      if (emp.managerId != null)
                        _row('Manager id', emp.managerId!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: const Text('Attendance'),
                    onPressed: () =>
                        context.pushNamed(RoutePaths.hrAttendanceName),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Payslips'),
                    onPressed: () =>
                        context.pushNamed(RoutePaths.hrPayslipsName),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Leave balance'),
                    onPressed: () =>
                        context.pushNamed(RoutePaths.hrLeaveBalanceName),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.blueGrey.shade100,
          child: Text(
            employee.name.isEmpty ? '?' : employee.name[0],
            style: const TextStyle(fontSize: 22),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                employee.position,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
