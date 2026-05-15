import 'package:erp_mobile/features/hr/domain/entities/employee.dart';
import 'package:erp_mobile/features/hr/domain/usecases/apply_employee_query.dart';
import 'package:test/test.dart';

Employee _e({
  required String id,
  required String name,
  String email = 'x@erp.example',
  String department = 'Sales',
  String position = 'Account Executive',
  EmploymentStatus status = EmploymentStatus.active,
  DateTime? hiredAt,
}) =>
    Employee(
      id: id,
      name: name,
      email: email,
      phone: '+855 12 345 678',
      department: department,
      position: position,
      hiredAt: hiredAt ?? DateTime.utc(2024, 1, 1),
      status: status,
      monthlySalary: r'$1,000.00',
    );

void main() {
  group('applyEmployeeQuery', () {
    final all = [
      _e(id: '1', name: 'Alice', department: 'Sales',
          hiredAt: DateTime.utc(2025, 6, 1)),
      _e(id: '2', name: 'Bob', department: 'Engineering',
          hiredAt: DateTime.utc(2024, 1, 15)),
      _e(id: '3', name: 'Charlie', department: 'Sales',
          status: EmploymentStatus.terminated,
          hiredAt: DateTime.utc(2023, 5, 1)),
      _e(id: '4', name: 'Diana', department: 'Finance', position: 'CFO',
          hiredAt: DateTime.utc(2022, 9, 9)),
    ];

    test('default sort is name ascending', () {
      final out = applyEmployeeQuery(all);
      expect(out.map((e) => e.name).toList(),
          ['Alice', 'Bob', 'Charlie', 'Diana']);
    });

    test('department filter narrows the list', () {
      final out = applyEmployeeQuery(all, departmentFilter: {'Sales'});
      expect(out.map((e) => e.id).toSet(), {'1', '3'});
    });

    test('status filter narrows the list', () {
      final out =
          applyEmployeeQuery(all, statusFilter: {EmploymentStatus.terminated});
      expect(out.single.id, '3');
    });

    test('search hits name, email, position case-insensitively', () {
      // Name match.
      expect(applyEmployeeQuery(all, searchQuery: 'AL').map((e) => e.id),
          ['1']);
      // Position match.
      expect(applyEmployeeQuery(all, searchQuery: 'cfo').single.id, '4');
    });

    test('recently hired sorts most-recent first', () {
      final out = applyEmployeeQuery(all, sort: EmployeeSort.recentlyHired);
      expect(out.first.name, 'Alice'); // 2025-06-01
      expect(out.last.name, 'Diana');  // 2022-09-09
    });

    test('department sort is stable on name within department', () {
      final out = applyEmployeeQuery(all, sort: EmployeeSort.departmentAsc);
      expect(out.map((e) => e.name).toList(),
          ['Bob', 'Diana', 'Alice', 'Charlie']);
    });

    test('empty input → empty output regardless of filters', () {
      expect(applyEmployeeQuery(const []), isEmpty);
      expect(
        applyEmployeeQuery(const [], departmentFilter: {'Sales'}),
        isEmpty,
      );
    });
  });

  group('extractDepartments', () {
    test('returns unique sorted department names', () {
      final out = extractDepartments([
        _e(id: '1', name: 'A', department: 'Sales'),
        _e(id: '2', name: 'B', department: 'Engineering'),
        _e(id: '3', name: 'C', department: 'Sales'),
        _e(id: '4', name: 'D', department: 'Finance'),
      ]);
      expect(out, ['Engineering', 'Finance', 'Sales']);
    });

    test('empty input → empty list', () {
      expect(extractDepartments(const []), isEmpty);
    });
  });
}
