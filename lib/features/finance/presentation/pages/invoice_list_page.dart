import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/usecases/apply_invoice_query.dart';
import '../bloc/invoice_list_bloc.dart';
import '../bloc/invoice_list_event.dart';
import '../bloc/invoice_list_state.dart';

/// Invoice list page (Slice 3.2.1) — search field + status chips +
/// sort dropdown + scrollable list.
class InvoiceListPage extends StatelessWidget {
  const InvoiceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InvoiceListBloc>(
      create: (_) => getIt<InvoiceListBloc>()
        ..add(const InvoiceListEvent.started()),
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
      appBar: AppBar(title: Text(l10n.invoiceListTitle)),
      body: Column(
        children: const [
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
    final bloc = context.read<InvoiceListBloc>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.invoiceListSearchHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (q) =>
                bloc.add(InvoiceListEvent.searchChanged(q)),
          ),
          const SizedBox(height: 8),
          BlocBuilder<InvoiceListBloc, InvoiceListState>(
            buildWhen: (a, b) =>
                a.statusFilter != b.statusFilter || a.sort != b.sort,
            builder: (context, state) => Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in InvoiceStatus.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(invoiceStatusLabel(l10n, s)),
                              selected: state.statusFilter.contains(s),
                              onSelected: (_) => bloc.add(
                                InvoiceListEvent.statusToggled(s),
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
  final InvoiceSort current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<InvoiceSort>(
      tooltip: l10n.invoiceListSortTooltip,
      icon: const Icon(Icons.sort),
      initialValue: current,
      onSelected: (s) =>
          context.read<InvoiceListBloc>().add(InvoiceListEvent.sortChanged(s)),
      itemBuilder: (_) => [
        for (final s in InvoiceSort.values)
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
    return BlocBuilder<InvoiceListBloc, InvoiceListState>(
      builder: (context, state) {
        if (state.isLoading && state.source.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.errorMessage != null && state.source.isEmpty) {
          return _CenteredMessage(
            text: l10n.invoiceListError(state.errorMessage!),
          );
        }
        if (state.visible.isEmpty) {
          return _CenteredMessage(text: l10n.invoiceListEmpty);
        }
        return ListView.separated(
          itemCount: state.visible.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (_, i) => _InvoiceTile(invoice: state.visible[i]),
        );
      },
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice});
  final Invoice invoice;

  static final _date = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            invoiceStatusColor(theme, invoice.status).withValues(alpha: 0.15),
        foregroundColor: invoiceStatusColor(theme, invoice.status),
        child: const Icon(Icons.receipt_long_outlined, size: 22),
      ),
      title: Row(
        children: [
          Text(
            invoice.invoiceNumber,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              invoice.customerName,
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
        '${_date.format(invoice.issuedAt.toLocal())} '
        '· ${l10n.invoiceListDueLabel(_date.format(invoice.dueAt.toLocal()))}',
        style: theme.textTheme.labelSmall,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            invoice.totalAmount,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          _StatusBadge(status: invoice.status),
        ],
      ),
      onTap: () => context.goNamed(
        RoutePaths.invoiceDetailName,
        pathParameters: {RoutePaths.invoiceDetailIdParam: invoice.id},
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = invoiceStatusColor(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        invoiceStatusLabel(l10n, status),
        style: theme.textTheme.labelSmall?.copyWith(color: color),
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
            Icon(Icons.receipt_long_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String invoiceStatusLabel(AppLocalizations l10n, InvoiceStatus s) {
  return switch (s) {
    InvoiceStatus.draft => l10n.invoiceStatusDraft,
    InvoiceStatus.pendingApproval => l10n.invoiceStatusPendingApproval,
    InvoiceStatus.approved => l10n.invoiceStatusApproved,
    InvoiceStatus.rejected => l10n.invoiceStatusRejected,
  };
}

Color invoiceStatusColor(ThemeData theme, InvoiceStatus s) {
  return switch (s) {
    InvoiceStatus.draft => theme.colorScheme.outline,
    InvoiceStatus.pendingApproval => theme.colorScheme.primary,
    InvoiceStatus.approved => theme.colorScheme.tertiary,
    InvoiceStatus.rejected => theme.colorScheme.error,
  };
}

String _sortLabel(AppLocalizations l10n, InvoiceSort s) {
  return switch (s) {
    InvoiceSort.issuedDateDesc => l10n.invoiceSortIssuedDesc,
    InvoiceSort.issuedDateAsc => l10n.invoiceSortIssuedAsc,
    InvoiceSort.dueDateAsc => l10n.invoiceSortDueAsc,
    InvoiceSort.amountDesc => l10n.invoiceSortAmountDesc,
    InvoiceSort.numberAsc => l10n.invoiceSortNumberAsc,
  };
}
