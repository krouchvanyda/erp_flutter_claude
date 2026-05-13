import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/goods_receipt.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/repositories/purchase_orders_repository.dart';
import 'po_list_page.dart' show PurchaseOrderStatusBadge;

/// PO detail (Slice 4.2.1) — header + line table with ordered/received
/// columns + receipt history. The "Record receipt" action wires Slice
/// 4.2.3 once the form page exists.
class PurchaseOrderDetailPage extends StatefulWidget {
  const PurchaseOrderDetailPage({super.key, required this.poId});

  final String poId;

  @override
  State<PurchaseOrderDetailPage> createState() =>
      _PurchaseOrderDetailPageState();
}

class _PurchaseOrderDetailPageState extends State<PurchaseOrderDetailPage> {
  late PurchaseOrdersRepository _repo;
  late Future<_DetailBundle> _future;

  @override
  void initState() {
    super.initState();
    _repo = getIt<PurchaseOrdersRepository>();
    _future = _load();
  }

  Future<_DetailBundle> _load() async {
    final po = await _repo.findById(widget.poId);
    if (po == null) return _DetailBundle(po: null, receipts: const []);
    final receipts = await _repo.receiptsFor(widget.poId);
    return _DetailBundle(po: po, receipts: receipts);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.poDetailTitle)),
      body: FutureBuilder<_DetailBundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bundle = snap.data;
          if (bundle == null || bundle.po == null) {
            return Center(child: Text(l10n.poDetailNotFound(widget.poId)));
          }
          return _Body(bundle: bundle);
        },
      ),
      bottomNavigationBar: FutureBuilder<_DetailBundle>(
        future: _future,
        builder: (context, snap) {
          final po = snap.data?.po;
          if (po == null) return const SizedBox.shrink();
          if (po.status == PurchaseOrderStatus.fullyReceived ||
              po.status == PurchaseOrderStatus.cancelled ||
              po.status == PurchaseOrderStatus.closed) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: () async {
                  await context.pushNamed(
                    RoutePaths.goodsReceiptNewName,
                    pathParameters: {
                      RoutePaths.goodsReceiptPoIdParam: po.id,
                    },
                  );
                  if (mounted) _reload();
                },
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(l10n.poDetailRecordReceiptAction),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailBundle {
  const _DetailBundle({required this.po, required this.receipts});
  final PurchaseOrder? po;
  final List<GoodsReceipt> receipts;
}

class _Body extends StatelessWidget {
  const _Body({required this.bundle});
  final _DetailBundle bundle;
  static final _date = DateFormat('yyyy-MM-dd');
  static final _dt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final po = bundle.po!;
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
                      child: Text(po.number,
                          style: theme.textTheme.titleLarge),
                    ),
                    PurchaseOrderStatusBadge(status: po.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(po.vendorName, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                      label: l10n.poDetailCreatedLabel,
                      value: _date.format(po.createdAt.toLocal()),
                    ),
                    _MetaChip(
                      label: l10n.poDetailExpectedLabel,
                      value: _date.format(po.expectedAt.toLocal()),
                    ),
                    if (po.sourcePurchaseRequestId != null)
                      _MetaChip(
                        label: l10n.poDetailSourcePrLabel,
                        value: po.sourcePurchaseRequestId!,
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
                child: Text(l10n.poDetailLinesHeading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ),
              for (final line in po.lineItems) _LineRow(line: line),
              const Divider(height: 0),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(l10n.poDetailTotalLabel,
                        style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      po.totalAmount,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(l10n.poDetailReceiptsHeading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ),
              if (bundle.receipts.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(l10n.poDetailReceiptsEmpty,
                      style: theme.textTheme.bodySmall),
                )
              else
                for (final r in bundle.receipts)
                  ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(_dt.format(r.receivedAt.toLocal())),
                    subtitle: Text(
                      r.note == null
                          ? r.receivedBy
                          : '${r.receivedBy} · ${r.note}',
                      style: theme.textTheme.labelSmall,
                    ),
                    trailing: Text(
                      l10n.poDetailReceiptItemsBadge(r.lines.length),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              const SizedBox(height: 8),
            ],
          ),
        ),
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

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final PurchaseOrderLine line;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final outstanding = line.outstandingQuantity;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(line.description,
                    style: theme.textTheme.bodyMedium),
              ),
              Text(
                line.lineTotal,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (line.sku != null)
            Text(line.sku!, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            children: [
              Text(
                l10n.poLineOrderedLabel(line.orderedQuantity.toString()),
                style: theme.textTheme.labelSmall,
              ),
              Text(
                l10n.poLineReceivedLabel(line.receivedQuantity.toString()),
                style: theme.textTheme.labelSmall,
              ),
              if (outstanding > 0)
                Text(
                  l10n.poLineOutstandingLabel(outstanding.toString()),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
