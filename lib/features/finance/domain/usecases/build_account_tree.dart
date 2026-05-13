import '../entities/account.dart';
import '../entities/account_tree_node.dart';

/// Pure-Dart chart-of-accounts tree builder (Slice 3.1.1).
///
/// Turns a flat `List<Account>` (the wire / drift shape) into a list of
/// recursively-populated [AccountTreeNode] roots. Sorted by `code` at
/// every level so the on-screen order is deterministic.
///
/// **Defensive against bad input**:
/// - **Orphans** (a non-null `parentId` that doesn't match any account
///   in the list) are promoted to roots so they remain visible —
///   silently dropping them would mask data-quality issues.
/// - **Cycles** (A→B→A) are broken: the second time the walker would
///   re-enter an already-visited node it stops the recursion. The
///   cycle-suppressed branch is logged via the optional [onCycle]
///   callback so callers can surface it (the bloc forwards to the
///   logger; tests inspect directly).
/// - **Duplicate ids** in the input collapse to the *first* occurrence
///   — duplicate writes are a server bug we shouldn't paper over by
///   randomly picking the latest.
///
/// Pure (no Flutter / drift) so the rules live in unit tests rather
/// than in widget rendering.
List<AccountTreeNode> buildAccountTree(
  Iterable<Account> flat, {
  void Function(String accountId)? onCycle,
}) {
  // First-write-wins de-dupe by id — preserves source order for the
  // (rare) case where dedupe matters for rendering.
  final byId = <String, Account>{};
  for (final a in flat) {
    byId.putIfAbsent(a.id, () => a);
  }

  // Children buckets keyed by parent id (or `null` for roots).
  final childrenOf = <String?, List<Account>>{};
  for (final a in byId.values) {
    final parent = a.parentId;
    final effectiveParent =
        parent == null || !byId.containsKey(parent) ? null : parent;
    childrenOf.putIfAbsent(effectiveParent, () => <Account>[]).add(a);
  }

  // Sort each bucket by code — ASCII compare is fine for typical
  // codes (`'1100' < '1100-01' < '1200'`); locale-aware sort can
  // come later if a real CoA needs it.
  for (final bucket in childrenOf.values) {
    bucket.sort((a, b) => a.code.compareTo(b.code));
  }

  final visited = <String>{};
  final roots = <AccountTreeNode>[
    ..._expand(
      parentId: null,
      childrenOf: childrenOf,
      visited: visited,
      depth: 0,
      onCycle: onCycle,
    ),
  ];

  // Stranded-cycle sweep: any account not visited above belongs to a
  // pure cycle (every node has a valid mutual parent — no `null` entry
  // existed to seed the recursion from). Promote the lowest-coded
  // member of each such subgraph to a root so the data appears, and
  // report every cycle node so the caller sees what happened.
  final stranded = byId.keys.where((id) => !visited.contains(id)).toList()
    ..sort((a, b) => byId[a]!.code.compareTo(byId[b]!.code));
  for (final id in stranded) {
    if (visited.contains(id)) continue; // walked as part of a prior sweep
    onCycle?.call(id);
    final account = byId[id]!;
    visited.add(id);
    roots.add(AccountTreeNode(
      account: account,
      depth: 0,
      children: _expand(
        parentId: id,
        childrenOf: childrenOf,
        visited: visited,
        depth: 1,
        onCycle: onCycle,
      ),
    ));
  }

  return roots;
}

List<AccountTreeNode> _expand({
  required String? parentId,
  required Map<String?, List<Account>> childrenOf,
  required Set<String> visited,
  required int depth,
  required void Function(String accountId)? onCycle,
}) {
  final children = childrenOf[parentId] ?? const <Account>[];
  return [
    for (final child in children)
      if (visited.add(child.id))
        AccountTreeNode(
          account: child,
          depth: depth,
          children: _expand(
            parentId: child.id,
            childrenOf: childrenOf,
            visited: visited,
            depth: depth + 1,
            onCycle: onCycle,
          ),
        )
      else
        // Cycle — surface to caller and stop the recursion. The
        // already-emitted node above this in the tree carries the
        // partial structure; the user just won't see the loopback.
        _reportCycle(child, onCycle),
  ].whereType<AccountTreeNode>().toList(growable: false);
}

/// Returns `null` so the list-comprehension can `whereType` past it.
/// Side effect: invokes the [onCycle] callback for diagnostics.
AccountTreeNode? _reportCycle(
  Account child,
  void Function(String accountId)? onCycle,
) {
  onCycle?.call(child.id);
  return null;
}
