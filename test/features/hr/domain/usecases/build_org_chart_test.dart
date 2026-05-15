import 'package:erp_mobile/features/hr/domain/entities/employee.dart';
import 'package:erp_mobile/features/hr/domain/usecases/build_org_chart.dart';
import 'package:test/test.dart';

Employee _e(String id, String name, {String? managerId}) => Employee(
      id: id,
      name: name,
      email: '$id@erp.example',
      phone: '+855',
      department: 'X',
      position: 'P',
      hiredAt: DateTime.utc(2024, 1, 1),
      status: EmploymentStatus.active,
      monthlySalary: r'$1,000.00',
      managerId: managerId,
    );

void main() {
  group('buildOrgChart', () {
    test('null managerId becomes a root', () {
      final roots = buildOrgChart([_e('a', 'Alice')]);
      expect(roots, hasLength(1));
      expect(roots.single.depth, 0);
      expect(roots.single.reports, isEmpty);
    });

    test('children attach to their manager and depth increments', () {
      final roots = buildOrgChart([
        _e('a', 'Alice'),
        _e('b', 'Bob', managerId: 'a'),
        _e('c', 'Carol', managerId: 'b'),
      ]);
      expect(roots, hasLength(1));
      expect(roots.single.employee.id, 'a');
      expect(roots.single.reports, hasLength(1));
      expect(roots.single.reports.single.depth, 1);
      expect(roots.single.reports.single.reports.single.depth, 2);
    });

    test('unknown managerId promotes to root rather than dropping the node',
        () {
      final roots = buildOrgChart([
        _e('a', 'Alice', managerId: 'ghost'), // ghost not in set
      ]);
      expect(roots, hasLength(1));
      expect(roots.single.employee.id, 'a');
    });

    test('siblings sort by name', () {
      final roots = buildOrgChart([
        _e('a', 'Alice'),
        _e('z', 'Zach', managerId: 'a'),
        _e('m', 'Mary', managerId: 'a'),
      ]);
      final reportNames =
          roots.single.reports.map((n) => n.employee.name).toList();
      expect(reportNames, ['Mary', 'Zach']);
    });

    test('cycle does not infinite-loop; each employee appears once', () {
      // a → b → a (synthetic cycle)
      final roots = buildOrgChart([
        _e('a', 'Alice', managerId: 'b'),
        _e('b', 'Bob', managerId: 'a'),
      ]);
      final flat = flattenOrgChart(roots);
      expect(flat.map((n) => n.employee.id).toSet(), {'a', 'b'});
    });

    test('flattenOrgChart visits parent before children depth-first', () {
      final roots = buildOrgChart([
        _e('a', 'Alice'),
        _e('b', 'Bob', managerId: 'a'),
        _e('c', 'Carol', managerId: 'a'),
      ]);
      final flat = flattenOrgChart(roots);
      expect(flat.map((n) => n.employee.name).toList(),
          ['Alice', 'Bob', 'Carol']);
    });
  });
}
