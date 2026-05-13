import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/repositories/sales_orders_repository.dart';
import '../../domain/usecases/advance_fulfillment.dart';
import 'sales_order_list_page.dart'
    show SalesOrderStatusBadge, salesOrderStatusLabel;

/// Sales order detail (Slice 6.2.1 + 6.2.3 fulfillment advance).
class SalesOrderDetailPage extends StatefulWidget {
  const SalesOrderDetailPage({super.key, required this.orderId});
  final String orderId;

  @override
  State<SalesOrderDetailPage> createState() => _SalesOrderDetailPageState();
}

class _SalesOrderDetailPageState extends State<SalesOrderDetailPage> {
  late Future<SalesOrder?> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<SalesOrdersRepository>().findById(widget.orderId);
  }

  void _reload() {
    setState(() {
      _future = getIt<SalesOrdersRepository>().findById(widget.orderId);
    });
  }

  Future<void> _advanceTo(
    SalesOrder order,
    SalesOrderStatus next, {
    String? tracking,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Run the pure transition first so an illegal hop / missing
      // tracking reference surfaces *before* we touch the repo.
      final updated = advanceFulfillment(
        order,
        to: next,
        now: DateTime.now().toUtc(),
        trackingReference: tracking,
      );
      await getIt<SalesOrdersRepository>().setStatus(
        order.id,
        updated.status,
        shippedAt: updated.shippedAt,
        deliveredAt: updated.deliveredAt,
        trackingReference: updated.trackingReference,
      );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.salesOrderAdvancedSnack(
            salesOrderStatusLabel(l10n, updated.status),
          )),
        ));
      _reload();
    } on ValidationFailure {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.salesOrderTrackingRequired),
        ));
    } on Failure catch (f) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.salesOrderAdvanceFailed(f.toString())),
        ));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.salesOrderAdvanceFailed(e.toString())),
        ));
    }
  }

  Future<String?> _promptTracking() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.salesOrderTrackingDialogTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.salesOrderTrackingLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.invoiceActionCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(ctrl.text.trim()),
            child: Text(l10n.salesOrderTrackingConfirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.salesOrderDetailTitle)),
      body: FutureBuilder<SalesOrder?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snap.data;
          if (order == null) {
            return Center(
                child: Text(l10n.salesOrderNotFound(widget.orderId)));
          }
          return _Body(order: order);
        },
      ),
      bottomNavigationBar: FutureBuilder<SalesOrder?>(
        future: _future,
        builder: (context, snap) {
          final order = snap.data;
          if (order == null) return const SizedBox.shrink();
          return SafeArea(child: _ActionBar(
            order: order,
            onAdvance: (next) async {
              String? tracking;
              if (next == SalesOrderStatus.shipped) {
                tracking = await _promptTracking();
                if (tracking == null) return;
              }
              await _advanceTo(order, next, tracking: tracking);
            },
          ));
        },
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.order, required this.onAdvance});
  final SalesOrder order;
  final ValueChanged<SalesOrderStatus> onAdvance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    switch (order.status) {
      case SalesOrderStatus.pending:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onAdvance(SalesOrderStatus.cancelled),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.salesOrderCancelAction),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onAdvance(SalesOrderStatus.packing),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(l10n.salesOrderStartPackingAction),
                ),
              ),
            ],
          ),
        );
      case SalesOrderStatus.packing:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onAdvance(SalesOrderStatus.cancelled),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.salesOrderCancelAction),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onAdvance(SalesOrderStatus.shipped),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: Text(l10n.salesOrderShipAction),
                ),
              ),
            ],
          ),
        );
      case SalesOrderStatus.shipped:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: () => onAdvance(SalesOrderStatus.delivered),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(l10n.salesOrderMarkDeliveredAction),
          ),
        );
      case SalesOrderStatus.delivered:
      case SalesOrderStatus.cancelled:
        return const SizedBox.shrink();
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order});
  final SalesOrder order;
  static final _date = DateFormat('yyyy-MM-dd');
  static final _stamp = DateFormat('yyyy-MM-dd HH:mm');

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
                      child: Text(order.number,
                          style: theme.textTheme.titleLarge),
                    ),
                    SalesOrderStatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(order.customerName, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                      label: l10n.salesOrderCreatedLabel,
                      value: _date.format(order.createdAt.toLocal()),
                    ),
                    if (order.sourceQuotationId != null)
                      _MetaChip(
                        label: l10n.salesOrderSourceQuotationLabel,
                        value: order.sourceQuotationId!,
                      ),
                    if (order.shippedAt != null)
                      _MetaChip(
                        label: l10n.salesOrderShippedAtLabel,
                        value: _stamp.format(order.shippedAt!.toLocal()),
                      ),
                    if (order.deliveredAt != null)
                      _MetaChip(
                        label: l10n.salesOrderDeliveredAtLabel,
                        value: _stamp.format(order.deliveredAt!.toLocal()),
                      ),
                    if (order.trackingReference != null)
                      _MetaChip(
                        label: l10n.salesOrderTrackingLabel,
                        value: order.trackingReference!,
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
                child: Text(l10n.salesOrderDetailLinesHeading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ),
              for (final line in order.lineItems)
                ListTile(
                  dense: true,
                  title: Text(line.description),
                  subtitle: line.sku == null ? null : Text(line.sku!),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
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
                    Text(order.totalAmount,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ],
                ),
              ),
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
