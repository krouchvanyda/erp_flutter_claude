import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/repositories/purchase_orders_repository.dart';

/// PO list (Slice 4.2.1) — read-only feed; no toolbar yet (sort/filter
/// can be added later when seed gets large enough to justify it).
class PurchaseOrderListPage extends StatelessWidget {
  const PurchaseOrderListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repo = getIt<PurchaseOrdersRepository>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.poListTitle)),
      body: FutureBuilder<List<PurchaseOrder>>(
        future: repo.getAll(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final pos = snap.data ?? const <PurchaseOrder>[];
          if (pos.isEmpty) {
            return Center(child: Text(l10n.poListEmpty));
          }
          return ListView.separated(
            itemCount: pos.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) => _Tile(po: pos[i]),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.po});
  final PurchaseOrder po;
  static final _date = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            poStatusColor(theme, po.status).withValues(alpha: 0.15),
        foregroundColor: poStatusColor(theme, po.status),
        child: const Icon(Icons.inventory_2_outlined, size: 22),
      ),
      title: Row(
        children: [
          Text(
            po.number,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              po.vendorName,
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
        l10n.poListExpectedLabel(_date.format(po.expectedAt.toLocal())),
        style: theme.textTheme.labelSmall,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            po.totalAmount,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          PurchaseOrderStatusBadge(status: po.status),
        ],
      ),
      onTap: () => context.goNamed(
        RoutePaths.purchaseOrderDetailName,
        pathParameters: {RoutePaths.purchaseOrderDetailIdParam: po.id},
      ),
    );
  }
}

class PurchaseOrderStatusBadge extends StatelessWidget {
  const PurchaseOrderStatusBadge({super.key, required this.status});
  final PurchaseOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = poStatusColor(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        poStatusLabel(l10n, status),
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

String poStatusLabel(AppLocalizations l10n, PurchaseOrderStatus s) {
  return switch (s) {
    PurchaseOrderStatus.open => l10n.poStatusOpen,
    PurchaseOrderStatus.partiallyReceived => l10n.poStatusPartial,
    PurchaseOrderStatus.fullyReceived => l10n.poStatusFull,
    PurchaseOrderStatus.closed => l10n.poStatusClosed,
    PurchaseOrderStatus.cancelled => l10n.poStatusCancelled,
  };
}

Color poStatusColor(ThemeData theme, PurchaseOrderStatus s) {
  return switch (s) {
    PurchaseOrderStatus.open => theme.colorScheme.primary,
    PurchaseOrderStatus.partiallyReceived => theme.colorScheme.tertiary,
    PurchaseOrderStatus.fullyReceived => theme.colorScheme.tertiary,
    PurchaseOrderStatus.closed => theme.colorScheme.outline,
    PurchaseOrderStatus.cancelled => theme.colorScheme.error,
  };
}
