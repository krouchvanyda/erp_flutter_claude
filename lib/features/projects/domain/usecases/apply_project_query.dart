import '../entities/project.dart';

/// Pure filter + sort over the project list (Slice 8.1.1).
List<Project> applyProjectQuery(
  List<Project> all, {
  Set<ProjectStatus> statusFilter = const {},
  String searchQuery = '',
  ProjectSort sort = ProjectSort.nameAsc,
}) {
  Iterable<Project> result = all;

  if (statusFilter.isNotEmpty) {
    result = result.where((p) => statusFilter.contains(p.status));
  }

  final q = searchQuery.trim().toLowerCase();
  if (q.isNotEmpty) {
    result = result.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.code.toLowerCase().contains(q) ||
        p.ownerName.toLowerCase().contains(q));
  }

  final list = result.toList();
  switch (sort) {
    case ProjectSort.nameAsc:
      list.sort((a, b) => a.name.compareTo(b.name));
    case ProjectSort.recentlyStarted:
      list.sort((a, b) => b.startDate.compareTo(a.startDate));
    case ProjectSort.dueSoonest:
      list.sort((a, b) => a.endDate.compareTo(b.endDate));
  }
  return list;
}
