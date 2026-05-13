import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/sales_quotation.dart';
import '../../domain/repositories/quotations_repository.dart';
import '../../domain/usecases/apply_quotation_query.dart';

/// Quotation list (Slice 6.2.1).
class QuotationListPage extends StatefulWidget {
  const QuotationListPage({super.key});

  @override
  State<QuotationListPage> createState() => _QuotationListPageState();
}

class _QuotationListPageState extends State<QuotationListPage> {
  late Future<List<SalesQuotation>> _future;
  final Set<QuotationStatus> _statusFilter = {};
  QuotationSort _sort = QuotationSort.createdDesc;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = getIt<QuotationsRepository>().getAll();
  }

  void _reload() {
    setState(() => _future = getIt<QuotationsRepository>().getAll());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.salesQuotationListTitle),
        actions: [
          IconButton(
            tooltip: l10n.salesQuotationNewTooltip,
            icon: const Icon(Icons.add),
            onPressed: () async {
              await context
                  .pushNamed(RoutePaths.salesQuotationNewName);
              if (mounted) _reload();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.salesQuotationSearchHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (q) => setState(() => _search = q),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final s in QuotationStatus.values) ...[
                              FilterChip(
                                label: Text(quotationStatusLabel(l10n, s)),
                                selected: _statusFilter.contains(s),
                                onSelected: (_) => setState(() {
                                  if (!_statusFilter.remove(s)) {
                                    _statusFilter.add(s);
                                  }
                                }),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<QuotationSort>(
                      tooltip: l10n.salesQuotationSortTooltip,
                      icon: const Icon(Icons.sort),
                      initialValue: _sort,
                      onSelected: (s) => setState(() => _sort = s),
                      itemBuilder: (_) => [
                        for (final s in QuotationSort.values)
                          PopupMenuItem(
                              value: s, child: Text(_sortLabel(l10n, s))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SalesQuotation>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? const <SalesQuotation>[];
                final visible = applyQuotationQuery(
                  all,
                  statusFilter: _statusFilter,
                  searchQuery: _search,
                  sort: _sort,
                );
                if (visible.isEmpty) {
                  return Center(
                      child: Text(l10n.salesQuotationListEmpty));
                }
                return ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) =>
                      _QuotationTile(quotation: visible[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _sortLabel(AppLocalizations l10n, QuotationSort s) {
    return switch (s) {
      QuotationSort.createdDesc => l10n.salesQuotationSortCreatedDesc,
      QuotationSort.createdAsc => l10n.salesQuotationSortCreatedAsc,
      QuotationSort.totalDesc => l10n.salesQuotationSortTotalDesc,
      QuotationSort.validityAsc => l10n.salesQuotationSortValidity,
    };
  }
}

class _QuotationTile extends StatelessWidget {
  const _QuotationTile({required this.quotation});
  final SalesQuotation quotation;
  static final _date = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = quotationStatusColor(theme, quotation.status);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        child: const Icon(Icons.request_quote_outlined),
      ),
      title: Row(
        children: [
          Text(
            quotation.number,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              quotation.customerName,
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
        '${_date.format(quotation.createdAt.toLocal())} · '
        '${l10n.salesQuotationValidUntilLabel(_date.format(quotation.validUntil.toLocal()))}',
        style: theme.textTheme.labelSmall,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            quotation.totalAmount,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          QuotationStatusBadge(status: quotation.status),
        ],
      ),
      onTap: () => context.goNamed(
        RoutePaths.salesQuotationDetailName,
        pathParameters: {
          RoutePaths.salesQuotationDetailIdParam: quotation.id,
        },
      ),
    );
  }
}

class QuotationStatusBadge extends StatelessWidget {
  const QuotationStatusBadge({super.key, required this.status});
  final QuotationStatus status;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = quotationStatusColor(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        quotationStatusLabel(l10n, status),
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

String quotationStatusLabel(AppLocalizations l10n, QuotationStatus s) {
  return switch (s) {
    QuotationStatus.draft => l10n.salesQuotationStatusDraft,
    QuotationStatus.sent => l10n.salesQuotationStatusSent,
    QuotationStatus.accepted => l10n.salesQuotationStatusAccepted,
    QuotationStatus.rejected => l10n.salesQuotationStatusRejected,
    QuotationStatus.expired => l10n.salesQuotationStatusExpired,
    QuotationStatus.converted => l10n.salesQuotationStatusConverted,
  };
}

Color quotationStatusColor(ThemeData theme, QuotationStatus s) {
  return switch (s) {
    QuotationStatus.draft => theme.colorScheme.outline,
    QuotationStatus.sent => theme.colorScheme.primary,
    QuotationStatus.accepted => theme.colorScheme.tertiary,
    QuotationStatus.rejected => theme.colorScheme.error,
    QuotationStatus.expired => theme.colorScheme.outline,
    QuotationStatus.converted => theme.colorScheme.secondary,
  };
}
