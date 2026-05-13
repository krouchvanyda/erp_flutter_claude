import '../entities/employee.dart';

/// Pure filter + sort over the employee list (Slice 7.1.1).
List<Employee> applyEmployeeQuery(
  List<Employee> all, {
  Set<String> departmentFilter = const {},
  Set<EmploymentStatus> statusFilter = const {},
  String searchQuery = '',
  EmployeeSort sort = EmployeeSort.nameAsc,
}) {
  Iterable<Employee> result = all;

  if (departmentFilter.isNotEmpty) {
    result = result.where((e) => departmentFilter.contains(e.department));
  }
  if (statusFilter.isNotEmpty) {
    result = result.where((e) => statusFilter.contains(e.status));
  }

  final q = searchQuery.trim().toLowerCase();
  if (q.isNotEmpty) {
    result = result.where((e) =>
        e.name.toLowerCase().contains(q) ||
        e.email.toLowerCase().contains(q) ||
        e.position.toLowerCase().contains(q));
  }

  final list = result.toList();
  switch (sort) {
    case EmployeeSort.nameAsc:
      list.sort((a, b) => a.name.compareTo(b.name));
    case EmployeeSort.recentlyHired:
      list.sort((a, b) => b.hiredAt.compareTo(a.hiredAt));
    case EmployeeSort.departmentAsc:
      list.sort((a, b) {
        final byDept = a.department.compareTo(b.department);
        return byDept != 0 ? byDept : a.name.compareTo(b.name);
      });
  }
  return list;
}

/// Unique department names sorted ascending — used to populate the
/// filter chip row.
List<String> extractDepartments(List<Employee> all) {
  final set = <String>{for (final e in all) e.department};
  final list = set.toList()..sort();
  return list;
}
