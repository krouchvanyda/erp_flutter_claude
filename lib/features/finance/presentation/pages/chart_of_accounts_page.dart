import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/account_tree_node.dart';
import '../account_type_visual.dart';
import '../bloc/account_tree_bloc.dart';
import '../bloc/account_tree_event.dart';
import '../bloc/account_tree_state.dart';

/// Chart of Accounts (Slice 3.1.1) — recursive tree view.
///
/// **Bloc lifecycle**: created per-mount via the DI factory and
/// immediately fed `Started`. Closing the page closes the bloc which
/// cancels the watch — same pattern as the notification inbox.
///
/// **Render strategy**: each level is laid out via `ListView` instead
/// of nested `ExpansionTile`s so the scroll position survives expand /
/// collapse. The bloc owns expansion state; the widget walks the tree
/// flatly into a list of visible rows.
class ChartOfAccountsPage extends StatelessWidget {
  const ChartOfAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountTreeBloc>(
      create: (_) => getIt<AccountTreeBloc>()
        ..add(const AccountTreeEvent.started()),
      child: const _ChartView(),
    );
  }
}

class _ChartView extends StatelessWidget {
  const _ChartView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chartOfAccountsTitle),
        actions: [
          BlocBuilder<AccountTreeBloc, AccountTreeState>(
            buildWhen: (a, b) =>
                (a is AccountTreeLoaded) != (b is AccountTreeLoaded),
            builder: (context, state) {
              if (state is! AccountTreeLoaded) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.chartOfAccountsExpandAll,
                    icon: const Icon(Icons.unfold_more),
                    onPressed: () => context
                        .read<AccountTreeBloc>()
                        .add(const AccountTreeEvent.expandedAll()),
                  ),
                  IconButton(
                    tooltip: l10n.chartOfAccountsCollapseAll,
                    icon: const Icon(Icons.unfold_less),
                    onPressed: () => context
                        .read<AccountTreeBloc>()
                        .add(const AccountTreeEvent.collapsedAll()),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<AccountTreeBloc, AccountTreeState>(
        builder: (context, state) => switch (state) {
          AccountTreeInitial() ||
          AccountTreeLoading() =>
            const Center(child: CircularProgressIndicator()),
          AccountTreeFailure(:final message) =>
            _CenteredMessage(text: l10n.chartOfAccountsError(message)),
          AccountTreeLoaded(:final roots, :final expandedIds) => roots.isEmpty
              ? _CenteredMessage(text: l10n.chartOfAccountsEmpty)
              : _AccountTreeList(roots: roots, expandedIds: expandedIds),
        },
      ),
    );
  }
}

class _AccountTreeList extends StatelessWidget {
  const _AccountTreeList({required this.roots, required this.expandedIds});

  final List<AccountTreeNode> roots;
  final Set<String> expandedIds;

  @override
  Widget build(BuildContext context) {
    final visible = <AccountTreeNode>[];
    void walk(List<AccountTreeNode> nodes) {
      for (final n in nodes) {
        visible.add(n);
        if (expandedIds.contains(n.account.id)) walk(n.children);
      }
    }

    walk(roots);

    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (_, i) => _AccountRow(
        node: visible[i],
        expanded: expandedIds.contains(visible[i].account.id),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.node, required this.expanded});

  final AccountTreeNode node;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = node.account;
    final bloc = context.read<AccountTreeBloc>();
    return ListTile(
      // 16dp base + 24dp per depth level. Keeps the relationship visible
      // without burning the right side at deep nesting.
      contentPadding:
          EdgeInsetsDirectional.only(start: 16 + (24.0 * node.depth), end: 16),
      leading: Icon(
        accountTypeIcon(account.type),
        color: theme.colorScheme.primary,
      ),
      title: Row(
        children: [
          Text(
            account.code,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: account.formattedBalance == null
          ? null
          : Text(
              account.formattedBalance!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: node.isLeaf
          ? null
          : Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: theme.colorScheme.onSurfaceVariant,
            ),
      // Slice 3.1.2 — leaf tap drills into the account detail page;
      // non-leaf tap toggles expansion (the original 3.1.1 behaviour).
      onTap: node.isLeaf
          ? () => context.goNamed(
                RoutePaths.accountDetailName,
                pathParameters: {
                  RoutePaths.accountDetailIdParam: account.id,
                },
              )
          : () => bloc.add(AccountTreeEvent.nodeToggled(account.id)),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
