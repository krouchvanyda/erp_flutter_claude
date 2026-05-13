import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/inventory_item.dart';
import '../bloc/items_list_bloc.dart';
import '../bloc/items_list_event.dart';
import '../bloc/items_list_state.dart';

/// Inventory item catalog (Slice 5.1.1) — search + warehouse chips +
/// "low stock only" filter + sort + scrollable list.
class ItemsListPage extends StatelessWidget {
  const ItemsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ItemsListBloc>(
      create: (_) => getIt<ItemsListBloc>()..add(const ItemsListStarted()),
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
        title: Text(l10n.inventoryItemsTitle),
        actions: [
          IconButton(
            tooltip: l10n.inventoryScanTooltip,
            icon: const Icon(Icons.qr_code_scanner_outlined),
            onPressed: () => context.goNamed(RoutePaths.inventoryScannerName),
          ),
          IconButton(
            tooltip: l10n.inventoryLowStockAlertsTooltip,
            icon: const Icon(Icons.warning_amber_outlined),
            onPressed: () =>
                context.goNamed(RoutePaths.inventoryLowStockName),
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
    final bloc = context.read<ItemsListBloc>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.inventoryItemsSearchHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (q) => bloc.add(ItemsListSearchChanged(q)),
          ),
          const SizedBox(height: 8),
          BlocBuilder<ItemsListBloc, ItemsListState>(
            buildWhen: (a, b) =>
                a.warehouseFilter != b.warehouseFilter ||
                a.onlyLowStock != b.onlyLowStock ||
                a.sort != b.sort ||
                a.availableWarehouses.length != b.availableWarehouses.length,
            builder: (context, state) => Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          avatar:
                              const Icon(Icons.warning_amber_outlined, size: 18),
                          label: Text(l10n.inventoryLowStockChip),
                          selected: state.onlyLowStock,
                          onSelected: (v) =>
                              bloc.add(ItemsListLowStockToggled(v)),
                        ),
                        const SizedBox(width: 8),
                        for (final wh in state.availableWarehouses) ...[
                          FilterChip(
                            label: Text(wh),
                            selected: state.warehouseFilter.contains(wh),
                            onSelected: (_) =>
                                bloc.add(ItemsListWarehouseToggled(wh)),
                          ),
                          const SizedBox(width: 8),
                        ],
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
  final InventoryItemSort current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<InventoryItemSort>(
      tooltip: l10n.inventoryItemsSortTooltip,
      icon: const Icon(Icons.sort),
      initialValue: current,
      onSelected: (s) =>
          context.read<ItemsListBloc>().add(ItemsListSortChanged(s)),
      itemBuilder: (_) => [
        for (final s in InventoryItemSort.values)
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
    return BlocBuilder<ItemsListBloc, ItemsListState>(
      builder: (context, state) {
        if (state.isLoading && state.source.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.errorMessage != null && state.source.isEmpty) {
          return _CenteredMessage(
            text: l10n.inventoryItemsError(state.errorMessage!),
          );
        }
        if (state.visible.isEmpty) {
          return _CenteredMessage(text: l10n.inventoryItemsEmpty);
        }
        return ListView.separated(
          itemCount: state.visible.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (_, i) => _ItemTile(item: state.visible[i]),
        );
      },
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final lowStock = item.isLowStock;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            inventoryStatusColor(theme, item).withValues(alpha: 0.15),
        foregroundColor: inventoryStatusColor(theme, item),
        child: const Icon(Icons.inventory_2_outlined, size: 22),
      ),
      title: Row(
        children: [
          Text(
            item.sku,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.name,
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
        '${item.warehouseCode} · ${item.locationCode}',
        style: theme.textTheme.labelSmall,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.inventoryItemsOnHand(item.onHandQty.toString()),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: lowStock ? theme.colorScheme.error : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (lowStock)
            Text(
              l10n.inventoryReorderBadge(item.reorderPoint.toString()),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      onTap: () => context.goNamed(
        RoutePaths.inventoryItemDetailName,
        pathParameters: {RoutePaths.inventoryItemDetailIdParam: item.id},
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
            Icon(Icons.inventory_2_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Color inventoryStatusColor(ThemeData theme, InventoryItem item) {
  if (item.status == InventoryItemStatus.discontinued) {
    return theme.colorScheme.outline;
  }
  if (item.status == InventoryItemStatus.blocked) {
    return theme.colorScheme.error;
  }
  if (item.isLowStock) return theme.colorScheme.error;
  return theme.colorScheme.tertiary;
}

String _sortLabel(AppLocalizations l10n, InventoryItemSort s) {
  return switch (s) {
    InventoryItemSort.nameAsc => l10n.inventorySortNameAsc,
    InventoryItemSort.skuAsc => l10n.inventorySortSkuAsc,
    InventoryItemSort.onHandAsc => l10n.inventorySortOnHandAsc,
    InventoryItemSort.onHandDesc => l10n.inventorySortOnHandDesc,
  };
}
