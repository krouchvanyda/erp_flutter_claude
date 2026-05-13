import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/validators/validators.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/items_repository.dart';
import '../../domain/usecases/transfer_stock.dart';

/// Stock transfer page (Slice 5.2.3) — picks a destination bin
/// (filtered to active items with the same SKU as the source by
/// default) and posts the two-leg ledger via [`TransferStockUseCase`].
class StockTransferPage extends StatefulWidget {
  const StockTransferPage({super.key, required this.sourceItemId});

  final String sourceItemId;

  @override
  State<StockTransferPage> createState() => _StockTransferPageState();
}

class _StockTransferPageState extends State<StockTransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late Future<_Bundle> _future;
  InventoryItem? _destination;
  String? _qtyError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Bundle> _load() async {
    final repo = getIt<ItemsRepository>();
    final source = await repo.findById(widget.sourceItemId);
    if (source == null) {
      return _Bundle(source: null, destinations: const []);
    }
    // Candidate destinations: same sku, different id, active.
    final all = await repo.getAll();
    final dests = all
        .where((i) =>
            i.id != source.id &&
            i.sku == source.sku &&
            i.status == InventoryItemStatus.active)
        .toList();
    return _Bundle(source: source, destinations: dests);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _resolveValidator(AppLocalizations l10n, String? code) {
    return switch (code) {
      'required' => l10n.validatorRequired,
      'invalid_number' => l10n.validatorInvalidNumber,
      'must_be_positive' => l10n.validatorMustBePositive,
      _ => '',
    };
  }

  Future<void> _submit(InventoryItem source) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_destination == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.inventoryTransferPickDestination),
        ));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _qtyError = null;
    });
    try {
      await getIt<TransferStockUseCase>()(
        sourceItemId: source.id,
        destinationItemId: _destination!.id,
        quantity: num.parse(_qtyCtrl.text.trim()),
        reference: _refCtrl.text.trim().isEmpty
            ? null
            : _refCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.inventoryTransferSuccess)));
      if (context.canPop()) context.pop();
    } on ValidationFailure catch (f) {
      final errs = f.fieldErrors['quantity'] ?? const [];
      final msg = errs.contains('exceeds_on_hand')
          ? l10n.inventoryQtyExceedsOnHand
          : l10n.validatorMustBePositive;
      setState(() {
        _submitting = false;
        _qtyError = msg;
      });
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
      appBar: AppBar(title: Text(l10n.inventoryTransferFormTitle)),
      body: FutureBuilder<_Bundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final source = snap.data?.source;
          if (source == null) {
            return Center(
              child: Text(l10n.inventoryItemNotFound(widget.sourceItemId)),
            );
          }
          final dests = snap.data!.destinations;
          return _Body(
            source: source,
            destinations: dests,
            destination: _destination,
            onDestinationChanged: (d) => setState(() => _destination = d),
            formKey: _formKey,
            qtyCtrl: _qtyCtrl,
            refCtrl: _refCtrl,
            noteCtrl: _noteCtrl,
            qtyError: _qtyError,
            submitting: _submitting,
            resolveValidator: (c) => _resolveValidator(l10n, c),
            onSubmit: () => _submit(source),
          );
        },
      ),
    );
  }
}

class _Bundle {
  const _Bundle({required this.source, required this.destinations});
  final InventoryItem? source;
  final List<InventoryItem> destinations;
}

class _Body extends StatelessWidget {
  const _Body({
    required this.source,
    required this.destinations,
    required this.destination,
    required this.onDestinationChanged,
    required this.formKey,
    required this.qtyCtrl,
    required this.refCtrl,
    required this.noteCtrl,
    required this.qtyError,
    required this.submitting,
    required this.resolveValidator,
    required this.onSubmit,
  });

  final InventoryItem source;
  final List<InventoryItem> destinations;
  final InventoryItem? destination;
  final ValueChanged<InventoryItem?> onDestinationChanged;
  final GlobalKey<FormState> formKey;
  final TextEditingController qtyCtrl;
  final TextEditingController refCtrl;
  final TextEditingController noteCtrl;
  final String? qtyError;
  final bool submitting;
  final String Function(String?) resolveValidator;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.inventoryTransferSourceHeading,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 4),
                  Text('${source.sku} · ${source.warehouseCode}/${source.locationCode}',
                      style: theme.textTheme.titleSmall),
                  Text(
                    l10n.inventoryFormCurrentOnHand(source.onHandQty.toString()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (destinations.isEmpty)
            Card(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.inventoryTransferNoDestinations),
              ),
            )
          else
            DropdownButtonFormField<InventoryItem>(
              initialValue: destination,
              decoration: InputDecoration(
                labelText: l10n.inventoryTransferDestinationLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final d in destinations)
                  DropdownMenuItem(
                    value: d,
                    child: Text(
                      '${d.warehouseCode}/${d.locationCode} '
                      '(${l10n.inventoryItemsOnHand(d.onHandQty.toString())})',
                    ),
                  ),
              ],
              onChanged: submitting || destinations.isEmpty
                  ? null
                  : onDestinationChanged,
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: l10n.inventoryFormQuantityLabel,
              border: const OutlineInputBorder(),
              errorText: qtyError,
            ),
            validator: (v) {
              final code = Validators.positiveNumber(v);
              if (code == null) return null;
              final msg = resolveValidator(code);
              return msg.isEmpty ? null : msg;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: refCtrl,
            decoration: InputDecoration(
              labelText: l10n.inventoryFormReferenceLabel,
              hintText: l10n.inventoryTransferReferenceHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.inventoryFormNoteLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: submitting || destinations.isEmpty ? null : onSubmit,
            icon: const Icon(Icons.swap_horiz_outlined),
            label: Text(l10n.inventoryTransferAction),
          ),
        ],
      ),
    );
  }
}
