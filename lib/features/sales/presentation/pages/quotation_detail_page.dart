import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/quotations_repository.dart';
import '../../data/repositories/sales_orders_repository.dart';
import '../../entities/sales_quotation.dart';
import 'quotation_list_page.dart' show QuotationStatusBadge;

/// Quotation detail (Slice 6.2.1 + 6.2.2 convert action).
class QuotationDetailPage extends StatefulWidget {
  const QuotationDetailPage({super.key, required this.quotationId});
  final String quotationId;

  @override
  State<QuotationDetailPage> createState() => _QuotationDetailPageState();
}

class _QuotationDetailPageState extends State<QuotationDetailPage> {
  late Future<SalesQuotation?> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<QuotationsRepository>().findById(widget.quotationId);
  }

  void _reload() {
    setState(() {
      _future = getIt<QuotationsRepository>().findById(widget.quotationId);
    });
  }

  Future<void> _setStatus(SalesQuotation q, QuotationStatus next) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await getIt<QuotationsRepository>().setStatus(q.id, next);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.salesQuotationStatusUpdated)));
      _reload();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.salesQuotationActionFailed(e.toString())),
        ));
    }
  }

  Future<void> _convert(SalesQuotation q) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome =
        convertQuotationToOrder(q, now: DateTime.now().toUtc());
    if (outcome.result != ConvertQuotationResult.ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(_convertErrorCopy(l10n, outcome.result)),
        ));
      return;
    }
    try {
      await getIt<SalesOrdersRepository>().create(outcome.draftOrder!);
      await getIt<QuotationsRepository>()
          .setStatus(q.id, outcome.updatedQuotation!.status);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.salesQuotationConvertedSnack)));
      _reload();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.salesQuotationActionFailed(e.toString())),
        ));
    }
  }

  static String _convertErrorCopy(
      AppLocalizations l10n, ConvertQuotationResult r) {
    return switch (r) {
      ConvertQuotationResult.notAccepted =>
        l10n.salesQuotationConvertNotAccepted,
      ConvertQuotationResult.alreadyConverted =>
        l10n.salesQuotationConvertAlready,
      ConvertQuotationResult.expired => l10n.salesQuotationConvertExpired,
      ConvertQuotationResult.ok => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.salesQuotationDetailTitle)),
      body: FutureBuilder<SalesQuotation?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final q = snap.data;
          if (q == null) {
            return Center(
                child: Text(l10n.salesQuotationNotFound(widget.quotationId)));
          }
          return _Body(quotation: q);
        },
      ),
      bottomNavigationBar: FutureBuilder<SalesQuotation?>(
        future: _future,
        builder: (context, snap) {
          final q = snap.data;
          if (q == null) return const SizedBox.shrink();
          return SafeArea(
              child: _ActionBar(
            quotation: q,
            onSetStatus: (s) => _setStatus(q, s),
            onConvert: () => _convert(q),
          ));
        },
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.quotation,
    required this.onSetStatus,
    required this.onConvert,
  });

  final SalesQuotation quotation;
  final ValueChanged<QuotationStatus> onSetStatus;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    switch (quotation.status) {
      case QuotationStatus.draft:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: () => onSetStatus(QuotationStatus.sent),
            icon: const Icon(Icons.send_outlined),
            label: Text(l10n.salesQuotationSendAction),
          ),
        );
      case QuotationStatus.sent:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onSetStatus(QuotationStatus.rejected),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.salesQuotationRejectAction),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onSetStatus(QuotationStatus.accepted),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.salesQuotationAcceptAction),
                ),
              ),
            ],
          ),
        );
      case QuotationStatus.accepted:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: onConvert,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(l10n.salesQuotationConvertAction),
          ),
        );
      case QuotationStatus.rejected:
      case QuotationStatus.expired:
      case QuotationStatus.converted:
        return const SizedBox.shrink();
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.quotation});
  final SalesQuotation quotation;
  static final _date = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(quotation.number,
                          style: theme.textTheme.titleLarge),
                    ),
                    QuotationStatusBadge(status: quotation.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(quotation.customerName,
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                      label: l10n.salesQuotationCreatedLabel,
                      value: _date.format(quotation.createdAt.toLocal()),
                    ),
                    _MetaChip(
                      label: l10n.salesQuotationValidUntilLabel2,
                      value: _date.format(quotation.validUntil.toLocal()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(l10n.salesQuotationDetailLinesHeading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ),
              for (final line in quotation.lineItems)
                ListTile(
                  dense: true,
                  title: Text(line.description),
                  subtitle: line.sku == null ? null : Text(line.sku!),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${line.quantity} × ${line.unitPrice}',
                          style: theme.textTheme.labelSmall),
                      Text(
                        line.lineTotal,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 0),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(l10n.salesQuotationTotalLabel,
                        style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text(quotation.totalAmount,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (quotation.notes != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.salesQuotationNotesHeading,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 6),
                  Text(quotation.notes!),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
