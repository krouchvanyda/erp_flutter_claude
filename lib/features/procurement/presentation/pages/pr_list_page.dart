import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/purchase_request.dart';
import '../bloc/pr_list_bloc.dart';
import '../bloc/pr_list_event.dart';
import '../bloc/pr_list_state.dart';

/// Purchase request list (Slice 4.1.1) — search + status chips + sort +
/// scrollable list, mirroring the invoice list at parity.
class PurchaseRequestListPage extends StatelessWidget {
  const PurchaseRequestListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PurchaseRequestListBloc>(
      create: (_) => getIt<PurchaseRequestListBloc>()
        ..add(const PurchaseRequestListStarted()),
      child: const _ListView(),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.prListTitle),
        actions: [
          IconButton(
            tooltip: l10n.prListNewTooltip,
            icon: const Icon(Icons.add),
            onPressed: () =>
                context.goNamed(RoutePaths.purchaseRequestNewName),
          ),
        ],
      ),
      body: const Column(
        children: [
          _Toolbar(),
          Expanded(child: _Body()),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bloc = context.read<PurchaseRequestListBloc>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.prListSearchHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (q) =>
                bloc.add(PurchaseRequestListSearchChanged(q)),
          ),
          const SizedBox(height: 8),
          BlocBuilder<PurchaseRequestListBloc, PurchaseRequestListState>(
            buildWhen: (a, b) =>
                a.statusFilter != b.statusFilter || a.sort != b.sort,
            builder: (context, state) => Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in PurchaseRequestStatus.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(prStatusLabel(l10n, s)),
                              selected: state.statusFilter.contains(s),
                              onSelected: (_) => bloc.add(
                                PurchaseRequestListStatusToggled(s),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SortMenu(current: state.sort),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.current});
  final PurchaseRequestSort current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<PurchaseRequestSort>(
      tooltip: l10n.prListSortTooltip,
      icon: const Icon(Icons.sort),
      initialValue: current,
      onSelected: (s) => context
          .read<PurchaseRequestListBloc>()
          .add(PurchaseRequestListSortChanged(s)),
      itemBuilder: (_) => [
        for (final s in PurchaseRequestSort.values)
          PopupMenuItem(value: s, child: Text(_sortLabel(l10n, s))),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<PurchaseRequestListBloc, PurchaseRequestListState>(
      builder: (context, state) {
        if (state.isLoading && state.source.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.errorMessage != null && state.source.isEmpty) {
          return _CenteredMessage(
            text: l10n.prListError(state.errorMessage!),
          );
        }
        if (state.visible.isEmpty) {
          return _CenteredMessage(text: l10n.prListEmpty);
        }
        return ListView.separated(
          itemCount: state.visible.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (_, i) => _PurchaseRequestTile(pr: state.visible[i]),
        );
      },
    );
  }
}

class _PurchaseRequestTile extends StatelessWidget {
  const _PurchaseRequestTile({required this.pr});
  final PurchaseRequest pr;

  static final _date = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            prStatusColor(theme, pr.status).withValues(alpha: 0.15),
        foregroundColor: prStatusColor(theme, pr.status),
        child: const Icon(Icons.shopping_cart_outlined, size: 22),
      ),
      title: Row(
        children: [
          Text(
            pr.number,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pr.requesterName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${_date.format(pr.createdAt.toLocal())} · ${pr.costCenter}',
        style: theme.textTheme.labelSmall,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            pr.totalAmount,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          PurchaseRequestStatusBadge(status: pr.status),
        ],
      ),
      onTap: () => context.goNamed(
        RoutePaths.purchaseRequestDetailName,
        pathParameters: {RoutePaths.purchaseRequestDetailIdParam: pr.id},
      ),
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
            Icon(Icons.shopping_cart_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class PurchaseRequestStatusBadge extends StatelessWidget {
  const PurchaseRequestStatusBadge({super.key, required this.status});
  final PurchaseRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = prStatusColor(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        prStatusLabel(l10n, status),
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

String prStatusLabel(AppLocalizations l10n, PurchaseRequestStatus s) {
  return switch (s) {
    PurchaseRequestStatus.draft => l10n.prStatusDraft,
    PurchaseRequestStatus.submitted => l10n.prStatusSubmitted,
    PurchaseRequestStatus.approved => l10n.prStatusApproved,
    PurchaseRequestStatus.rejected => l10n.prStatusRejected,
    PurchaseRequestStatus.converted => l10n.prStatusConverted,
  };
}

Color prStatusColor(ThemeData theme, PurchaseRequestStatus s) {
  return switch (s) {
    PurchaseRequestStatus.draft => theme.colorScheme.outline,
    PurchaseRequestStatus.submitted => theme.colorScheme.primary,
    PurchaseRequestStatus.approved => theme.colorScheme.tertiary,
    PurchaseRequestStatus.rejected => theme.colorScheme.error,
    PurchaseRequestStatus.converted => theme.colorScheme.onSurfaceVariant,
  };
}

String _sortLabel(AppLocalizations l10n, PurchaseRequestSort s) {
  return switch (s) {
    PurchaseRequestSort.createdDesc => l10n.prSortCreatedDesc,
    PurchaseRequestSort.createdAsc => l10n.prSortCreatedAsc,
    PurchaseRequestSort.totalDesc => l10n.prSortTotalDesc,
    PurchaseRequestSort.numberAsc => l10n.prSortNumberAsc,
  };
}
