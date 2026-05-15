import '../entities/audit_log_entry.dart';

/// Slice 9.3.2 — pure filter + search over the audit log.
///
/// `actionFilter` empty = all actions; same with `actorFilter`.
/// `searchQuery` matches actor name, target label, and detail.
/// Always sorts most-recent-first.
List<AuditLogEntry> queryAuditLog(
  List<AuditLogEntry> entries, {
  Set<AuditAction> actionFilter = const {},
  Set<String> actorFilter = const {},
  String searchQuery = '',
  DateTime? from,
  DateTime? to,
}) {
  Iterable<AuditLogEntry> result = entries;

  if (actionFilter.isNotEmpty) {
    result = result.where((e) => actionFilter.contains(e.action));
  }
  if (actorFilter.isNotEmpty) {
    result = result.where((e) => actorFilter.contains(e.actorId));
  }
  if (from != null) {
    final f = DateTime.utc(from.year, from.month, from.day);
    result = result.where((e) => !e.occurredAt.isBefore(f));
  }
  if (to != null) {
    final t = DateTime.utc(to.year, to.month, to.day, 23, 59, 59);
    result = result.where((e) => !e.occurredAt.isAfter(t));
  }

  final q = searchQuery.trim().toLowerCase();
  if (q.isNotEmpty) {
    result = result.where((e) =>
        e.actorName.toLowerCase().contains(q) ||
        e.targetLabel.toLowerCase().contains(q) ||
        (e.detail?.toLowerCase().contains(q) ?? false));
  }

  final list = result.toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return list;
}

/// Distinct actors present in the log — populates the actor filter
/// dropdown.
List<({String id, String name})> extractActors(
    List<AuditLogEntry> entries) {
  final byId = <String, String>{};
  for (final e in entries) {
    byId.putIfAbsent(e.actorId, () => e.actorName);
  }
  final out = byId.entries.map((e) => (id: e.key, name: e.value)).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return out;
}
