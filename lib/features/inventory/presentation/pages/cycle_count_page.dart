import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/cycle_count.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/items_repository.dart';
import '../../domain/usecases/apply_cycle_count.dart';

/// Cycle count page (Slice 5.2.4) — picks a warehouse, lists every
/// item in that warehouse, and lets the counter punch in the counted
/// quantity for each. On submit, runs [`ApplyCycleCountUseCase`].
class CycleCountPage extends StatefulWidget {
  const CycleCountPage({super.key});

  @override
  State<CycleCountPage> createState() => _CycleCountPageState();
}

class _CycleCountPageState extends State<CycleCountPage> {
  late Future<List<InventoryItem>> _itemsFuture;
  final Map<String, TextEditingController> _ctrls = {};
  String? _warehouseFilter;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _itemsFuture = getIt<ItemsRepository>().getAll();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(InventoryItem item) {
    return _ctrls.putIfAbsent(
      item.id,
      () => TextEditingController(text: item.onHandQty.toString()),
    );
  }

  Future<void> _submit(List<InventoryItem> items) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final lines = <CycleCountLine>[];
    for (final item in items) {
      if (_warehouseFilter != null &&
          item.warehouseCode != _warehouseFilter) {
        continue;
      }
      final raw = _ctrlFor(item).text.trim();
      final counted = num.tryParse(raw);
      if (counted == null) continue;
      lines.add(CycleCountLine(
        itemId: item.id,
        expectedQty: item.onHandQty,
        countedQty: counted,
      ));
    }
    if (lines.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.inventoryCycleEmpty)));
      return;
    }

    setState(() => _submitting = true);
    final count = CycleCount(
      id: 'CYCLE-${DateTime.now().millisecondsSinceEpoch}',
      warehouseCode: _warehouseFilter ?? items.first.warehouseCode,
      locationCode: '*',
      startedAt: DateTime.now().toUtc(),
      lines: lines,
    );

    try {
      final out = await getIt<ApplyCycleCountUseCase>()(count);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.inventoryCycleSuccess(
            out.adjustmentsPosted.length,
            out.totalVariance.toString(),
          )),
        ));
      if (context.canPop()) context.pop();
    } on Failure catch (f) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.inventoryMovementFailed(f.toString())),
        ));
      if (mounted) setState(() => _submitting = false);
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.inventoryMovementFailed(e.toString())),
        ));
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventoryCycleCountTitle)),
      body: FutureBuilder<List<InventoryItem>>(
        future: _itemsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <InventoryItem>[];
          if (items.isEmpty) {
            return Center(child: Text(l10n.inventoryCycleNoItems));
          }
          final warehouses = items.map((i) => i.warehouseCode).toSet().toList()
            ..sort();
          final filtered = _warehouseFilter == null
              ? items
              : items
                  .where((i) => i.warehouseCode == _warehouseFilter)
                  .toList();
          return Column(
            children: [
              _WarehouseChips(
                warehouses: warehouses,
                selected: _warehouseFilter,
                onChanged: (wh) => setState(() => _warehouseFilter = wh),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) => _CycleLine(
                    item: filtered[i],
                    controller: _ctrlFor(filtered[i]),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _submitting ? null : () => _submit(items),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(l10n.inventoryCycleSubmitAction),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WarehouseChips extends StatelessWidget {
  const _WarehouseChips({
    required this.warehouses,
    required this.selected,
    required this.onChanged,
  });

  final List<String> warehouses;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: Text(l10n.inventoryCycleAllWarehouses),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
            const SizedBox(width: 8),
            for (final wh in warehouses) ...[
              FilterChip(
                label: Text(wh),
                selected: selected == wh,
                onSelected: (_) => onChanged(wh),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _CycleLine extends StatelessWidget {
  const _CycleLine({required this.item, required this.controller});
  final InventoryItem item;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.sku, style: theme.textTheme.titleSmall),
                Text(
                  '${item.warehouseCode}/${item.locationCode}',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  l10n.inventoryCycleExpectedLabel(
                    item.onHandQty.toString(),
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.inventoryCycleCountedLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
