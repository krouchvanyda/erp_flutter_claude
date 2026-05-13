import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/validators/validators.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/items_repository.dart';
import '../../domain/usecases/record_stock_movement.dart';

/// Generic stock-movement form (Slice 5.2.2). Same widget handles
/// goods-receipt and goods-issue — the [type] argument decides label
/// copy + button colour + the use-case branch.
///
/// **No bloc** — single submit, no streaming state. A `FutureBuilder`
/// loads the item header so the form can render its current on-hand
/// alongside the quantity input.
class StockMovementFormPage extends StatefulWidget {
  const StockMovementFormPage({
    super.key,
    required this.itemId,
    required this.type,
  });

  final String itemId;
  final StockMovementType type;

  @override
  State<StockMovementFormPage> createState() => _StockMovementFormPageState();
}

class _StockMovementFormPageState extends State<StockMovementFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late Future<InventoryItem?> _itemFuture;
  String? _qtyError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _itemFuture = getIt<ItemsRepository>().findById(widget.itemId);
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

  Future<void> _submit(InventoryItem item) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _qtyError = null;
    });

    try {
      await getIt<RecordStockMovementUseCase>()(
        itemId: item.id,
        type: widget.type,
        quantity: num.parse(_qtyCtrl.text.trim()),
        reference: _refCtrl.text.trim().isEmpty
            ? null
            : _refCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(_successCopy(l10n, widget.type)),
        ));
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
          content: Text(l10n.inventoryMovementFailed(
            f.toString(),
          )),
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

  String _titleCopy(AppLocalizations l10n) {
    return switch (widget.type) {
      StockMovementType.receipt => l10n.inventoryReceiptFormTitle,
      StockMovementType.issue => l10n.inventoryIssueFormTitle,
      _ => l10n.inventoryItemDetailTitle,
    };
  }

  String _successCopy(AppLocalizations l10n, StockMovementType t) {
    return switch (t) {
      StockMovementType.receipt => l10n.inventoryReceiptSuccessSnack,
      StockMovementType.issue => l10n.inventoryIssueSuccessSnack,
      _ => l10n.inventoryMovementGenericSuccess,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_titleCopy(l10n))),
      body: FutureBuilder<InventoryItem?>(
        future: _itemFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final item = snap.data;
          if (item == null) {
            return Center(
              child: Text(l10n.inventoryItemNotFound(widget.itemId)),
            );
          }
          return _Body(
            item: item,
            type: widget.type,
            formKey: _formKey,
            qtyCtrl: _qtyCtrl,
            refCtrl: _refCtrl,
            noteCtrl: _noteCtrl,
            qtyError: _qtyError,
            submitting: _submitting,
            resolveValidator: (c) => _resolveValidator(l10n, c),
            onSubmit: () => _submit(item),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.item,
    required this.type,
    required this.formKey,
    required this.qtyCtrl,
    required this.refCtrl,
    required this.noteCtrl,
    required this.qtyError,
    required this.submitting,
    required this.resolveValidator,
    required this.onSubmit,
  });

  final InventoryItem item;
  final StockMovementType type;
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
                  Text(item.sku, style: theme.textTheme.titleMedium),
                  Text(item.name, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    l10n.inventoryFormCurrentOnHand(item.onHandQty.toString()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
              hintText: type == StockMovementType.receipt
                  ? l10n.inventoryFormReferenceReceiptHint
                  : l10n.inventoryFormReferenceIssueHint,
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
            onPressed: submitting ? null : onSubmit,
            icon: Icon(type == StockMovementType.receipt
                ? Icons.inbox_outlined
                : Icons.outbox_outlined),
            label: Text(type == StockMovementType.receipt
                ? l10n.inventoryReceiptAction
                : l10n.inventoryIssueAction),
            style: type == StockMovementType.receipt
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.tertiary,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
