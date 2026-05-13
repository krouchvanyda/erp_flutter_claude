import '../entities/employee.dart';

/// One node of the org tree. The chart is a forest — multiple roots are
/// possible when the company has more than one C-level (or when the
/// dataset is incomplete and a manager is missing).
class OrgNode {
  OrgNode({required this.employee, required this.depth, required this.reports});

  final Employee employee;
  final int depth;
  final List<OrgNode> reports;
}

/// Slice 7.1.3 — builds the manager-tree from a flat employee list.
///
/// **Invariants** the chart relies on:
/// - Each employee appears exactly once across the forest.
/// - An employee whose `managerId` is null OR points at an unknown id
///   becomes a root. The "unknown id" case is important — without this
///   fallback, a stale managerId would silently delete a sub-tree.
/// - Children are sorted by name so the tree is deterministic.
/// - Cycles (A → B → A) are broken at the second visit by promoting the
///   later employee to a root — defensive, since seed data shouldn't
///   contain cycles but we don't want the UI to recurse forever.
List<OrgNode> buildOrgChart(List<Employee> all) {
  final byId = {for (final e in all) e.id: e};

  // Effective manager id: null OR pointing at someone outside the set
  // collapses to null (root).
  String? effectiveManager(Employee e) {
    final m = e.managerId;
    if (m == null || !byId.containsKey(m)) return null;
    return m;
  }

  final children = <String?, List<Employee>>{};
  for (final e in all) {
    final m = effectiveManager(e);
    (children[m] ??= <Employee>[]).add(e);
  }
  for (final list in children.values) {
    list.sort((a, b) => a.name.compareTo(b.name));
  }

  final visited = <String>{};

  List<OrgNode> build(String? managerId, int depth) {
    final list = children[managerId] ?? const <Employee>[];
    final out = <OrgNode>[];
    for (final e in list) {
      if (!visited.add(e.id)) continue; // cycle guard
      out.add(OrgNode(
        employee: e,
        depth: depth,
        reports: build(e.id, depth + 1),
      ));
    }
    return out;
  }

  final roots = build(null, 0);

  // Cycle survivors: any employee not yet visited gets promoted to a
  // root so they don't vanish from the chart.
  for (final e in all) {
    if (visited.contains(e.id)) continue;
    roots.add(OrgNode(
      employee: e,
      depth: 0,
      reports: build(e.id, 1),
    ));
  }
  return roots;
}

/// Convenience traversal — flattens the forest in display order
/// (depth-first, children after parent) so the page can render a single
/// `ListView.builder`.
List<OrgNode> flattenOrgChart(List<OrgNode> roots) {
  final out = <OrgNode>[];
  void walk(OrgNode n) {
    out.add(n);
    for (final c in n.reports) {
      walk(c);
    }
  }

  for (final r in roots) {
    walk(r);
  }
  return out;
}
