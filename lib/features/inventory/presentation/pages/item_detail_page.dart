import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/items_repository.dart';
import '../../domain/repositories/stock_movements_repository.dart';
import 'items_list_page.dart' show inventoryStatusColor;

/// Item detail (Slice 5.1.2) — header card with stock numbers + a
/// chronologically-descending list of movements. The "Issue" /
/// "Receive" / "Transfer" actions on the bottom bar drop into Slice
/// 5.2.x flows.
class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  late ItemsRepository _itemsRepo;
  late StockMovementsRepository _movementsRepo;
  late Future<_Bundle> _future;

  @override
  void initState() {
    super.initState();
    _itemsRepo = getIt<ItemsRepository>();
    _movementsRepo = getIt<StockMovementsRepository>();
    _future = _load();
  }

  Future<_Bundle> _load() async {
    final item = await _itemsRepo.findById(widget.itemId);
    if (item == null) return _Bundle(item: null, movements: const []);
    final movements = await _movementsRepo.forItem(widget.itemId);
    return _Bundle(item: item, movements: movements);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventoryItemDetailTitle)),
      body: FutureBuilder<_Bundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bundle = snap.data;
          if (bundle == null || bundle.item == null) {
            return Center(
              child: Text(l10n.inventoryItemNotFound(widget.itemId)),
            );
          }
          return _Body(bundle: bundle);
        },
      ),
      bottomNavigationBar: FutureBuilder<_Bundle>(
        future: _future,
        builder: (context, snap) {
          final item = snap.data?.item;
          if (item == null) return const SizedBox.shrink();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await context.pushNamed(
                          RoutePaths.inventoryGoodsIssueName,
                          pathParameters: {
                            RoutePaths.inventoryItemDetailIdParam: item.id,
                          },
                        );
                        if (mounted) _reload();
                      },
                      icon: const Icon(Icons.outbox_outlined),
                      label: Text(l10n.inventoryIssueAction),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await context.pushNamed(
                          RoutePaths.inventoryGoodsReceiptName,
                          pathParameters: {
                            RoutePaths.inventoryItemDetailIdParam: item.id,
                          },
                        );
                        if (mounted) _reload();
                      },
                      icon: const Icon(Icons.inbox_outlined),
                      label: Text(l10n.inventoryReceiptAction),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await context.pushNamed(
                          RoutePaths.inventoryTransferName,
                          pathParameters: {
                            RoutePaths.inventoryItemDetailIdParam: item.id,
                          },
                        );
                        if (mounted) _reload();
                      },
                      icon: const Icon(Icons.swap_horiz_outlined),
                      label: Text(l10n.inventoryTransferAction),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Bundle {
  const _Bundle({required this.item, required this.movements});
  final InventoryItem? item;
  final List<StockMovement> movements;
}

class _Body extends StatelessWidget {
  const _Body({required this.bundle});
  final _Bundle bundle;
  static final _stamp = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final item = bundle.item!;
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
                      child: Text(item.sku,
                          style: theme.textTheme.titleLarge),
                    ),
                    _StockBadge(item: item),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.name, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                        label: l10n.inventoryDetailWarehouseLabel,
                        value: item.warehouseCode),
                    _MetaChip(
                        label: l10n.inventoryDetailLocationLabel,
                        value: item.locationCode),
                    _MetaChip(
                        label: l10n.inventoryDetailReorderLabel,
                        value: item.reorderPoint.toString()),
                    _MetaChip(
                        label: l10n.inventoryDetailUnitCostLabel,
                        value: item.unitCost),
                    if (item.barcode != null)
                      _MetaChip(
                          label: l10n.inventoryDetailBarcodeLabel,
                          value: item.barcode!),
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
                child: Text(l10n.inventoryDetailMovementsHeading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ),
              if (bundle.movements.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(l10n.inventoryDetailMovementsEmpty,
                      style: theme.textTheme.bodySmall),
                )
              else
                for (final m in bundle.movements)
                  _MovementRow(movement: m, stampFmt: _stamp),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.item});
  final InventoryItem item;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = inventoryStatusColor(theme, item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        l10n.inventoryItemsOnHand(item.onHandQty.toString()),
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
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

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement, required this.stampFmt});
  final StockMovement movement;
  final DateFormat stampFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = _typeColor(theme, movement.type);
    final signed = _signedLabel(movement);
    return ListTile(
      leading: Icon(_typeIcon(movement.type), color: color),
      title: Text(_typeLabel(l10n, movement.type)),
      subtitle: Text(
        movement.reference == null
            ? stampFmt.format(movement.postedAt.toLocal())
            : '${stampFmt.format(movement.postedAt.toLocal())} · ${movement.reference}',
        style: theme.textTheme.labelSmall,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            signed,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            l10n.inventoryMovementRunningLabel(
              movement.runningQty.toString(),
            ),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  static Color _typeColor(ThemeData theme, StockMovementType t) {
    return switch (t) {
      StockMovementType.receipt => theme.colorScheme.tertiary,
      StockMovementType.issue => theme.colorScheme.primary,
      StockMovementType.transfer => theme.colorScheme.secondary,
      StockMovementType.adjustment => theme.colorScheme.error,
    };
  }

  static IconData _typeIcon(StockMovementType t) {
    return switch (t) {
      StockMovementType.receipt => Icons.inbox_outlined,
      StockMovementType.issue => Icons.outbox_outlined,
      StockMovementType.transfer => Icons.swap_horiz_outlined,
      StockMovementType.adjustment => Icons.tune,
    };
  }

  static String _typeLabel(AppLocalizations l10n, StockMovementType t) {
    return switch (t) {
      StockMovementType.receipt => l10n.inventoryMovementTypeReceipt,
      StockMovementType.issue => l10n.inventoryMovementTypeIssue,
      StockMovementType.transfer => l10n.inventoryMovementTypeTransfer,
      StockMovementType.adjustment => l10n.inventoryMovementTypeAdjustment,
    };
  }

  /// Receipts read as `+N`, issues as `−N`, transfers carry their own
  /// sign (the leg of the transfer that posted decides), and adjustments
  /// surface whatever signed value was recorded.
  static String _signedLabel(StockMovement m) {
    final n = m.quantity;
    switch (m.type) {
      case StockMovementType.receipt:
        return '+${n.abs()}';
      case StockMovementType.issue:
        return '−${n.abs()}';
      case StockMovementType.transfer:
      case StockMovementType.adjustment:
        if (n >= 0) return '+$n';
        return '−${n.abs()}';
    }
  }
}
