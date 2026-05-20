import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/quotations_repository.dart';
import '../../entities/sales_quotation.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: l10n.salesQuotationListTitle,
        centerTitle: true,
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
      body: DynamicStatusBar(
        child: Stack(
          children: [
            // Background Canvas Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.12),
                    theme.colorScheme.surface,
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.04),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(height: context.dynamicAppBarPadding),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.015),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                            hintText: l10n.salesQuotationSearchHint,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (q) => setState(() => _search = q),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
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
                                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                      checkmarkColor: theme.colorScheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadii.md),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: PopupMenuButton<QuotationSort>(
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.02, end: 0),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.request_quote_outlined, size: 48, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.salesQuotationListEmpty,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 40),
                        physics: const BouncingScrollPhysics(),
                        itemCount: visible.length,
                        itemBuilder: (_, i) =>
                            _QuotationTile(quotation: visible[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.request_quote_outlined, color: color, size: 24),
          ),
          title: Row(
            children: [
              Text(
                quotation.number,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
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
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '${_date.format(quotation.createdAt.toLocal())} • '
              '${l10n.salesQuotationValidUntilLabel(_date.format(quotation.validUntil.toLocal()))}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                quotation.totalAmount,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              QuotationStatusBadge(status: quotation.status),
            ],
          ),
          onTap: () => context.pushNamed(
            RoutePaths.salesQuotationDetailName,
            pathParameters: {
              RoutePaths.salesQuotationDetailIdParam: quotation.id,
            },
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.02, end: 0);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        quotationStatusLabel(l10n, status),
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
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
