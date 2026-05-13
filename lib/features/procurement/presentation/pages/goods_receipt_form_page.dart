import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/goods_receipt.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/repositories/purchase_orders_repository.dart';
import '../../domain/usecases/validate_goods_receipt.dart';

/// Goods receipt entry form (Slice 4.2.3).
///
/// Loads the PO once, lets the user enter a quantity per outstanding
/// line + a "received by" name + optional note, validates with the
/// pure [`validateGoodsReceipt`], then persists via the repo.
class GoodsReceiptFormPage extends StatefulWidget {
  const GoodsReceiptFormPage({super.key, required this.purchaseOrderId});

  final String purchaseOrderId;

  @override
  State<GoodsReceiptFormPage> createState() => _GoodsReceiptFormPageState();
}

class _GoodsReceiptFormPageState extends State<GoodsReceiptFormPage> {
  late PurchaseOrdersRepository _repo;
  late Future<PurchaseOrder?> _poFuture;
  final _receivedBy = TextEditingController();
  final _note = TextEditingController();
  final Map<String, TextEditingController> _qtyByLineId = {};
  final _formKey = GlobalKey<FormState>();
  String? _formError;

  @override
  void initState() {
    super.initState();
    _repo = getIt<PurchaseOrdersRepository>();
    _poFuture = _repo.findById(widget.purchaseOrderId);
  }

  @override
  void dispose() {
    _receivedBy.dispose();
    _note.dispose();
    for (final c in _qtyByLineId.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String id) =>
      _qtyByLineId.putIfAbsent(id, TextEditingController.new);

  String _errorMessage(AppLocalizations l10n, GoodsReceiptError e) {
    return switch (e) {
      GoodsReceiptError.poClosed => l10n.goodsReceiptErrorPoClosed,
      GoodsReceiptError.noLines => l10n.goodsReceiptErrorNoLines,
      GoodsReceiptError.nonPositiveQuantity =>
        l10n.goodsReceiptErrorNonPositive,
      GoodsReceiptError.unknownLineId => l10n.goodsReceiptErrorUnknownLine,
      GoodsReceiptError.exceedsOutstanding =>
        l10n.goodsReceiptErrorExceedsOutstanding,
    };
  }

  Future<void> _submit(PurchaseOrder po) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final lines = <GoodsReceiptLine>[];
    for (final pol in po.lineItems) {
      final raw = _ctrl(pol.id).text.trim();
      if (raw.isEmpty) continue;
      final qty = num.tryParse(raw);
      if (qty == null || qty == 0) continue;
      lines.add(GoodsReceiptLine(purchaseOrderLineId: pol.id, quantity: qty));
    }

    final receipt = GoodsReceipt(
      id: 'tmp',
      purchaseOrderId: po.id,
      receivedAt: DateTime.now().toUtc(),
      receivedBy: _receivedBy.text.trim(),
      lines: lines,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    final err = validateGoodsReceipt(receipt, po);
    if (err != null) {
      setState(() => _formError = _errorMessage(l10n, err));
      return;
    }

    try {
      await _repo.recordGoodsReceipt(receipt);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.goodsReceiptSavedSnack)));
      if (context.canPop()) context.pop();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.goodsReceiptSaveFailed(e.toString())),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.goodsReceiptFormTitle)),
      body: FutureBuilder<PurchaseOrder?>(
        future: _poFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final po = snap.data;
          if (po == null) {
            return Center(
                child: Text(l10n.poDetailNotFound(widget.purchaseOrderId)));
          }
          return _Body(
            po: po,
            formKey: _formKey,
            receivedBy: _receivedBy,
            note: _note,
            controllerFor: _ctrl,
            formError: _formError,
            onSubmit: () => _submit(po),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.po,
    required this.formKey,
    required this.receivedBy,
    required this.note,
    required this.controllerFor,
    required this.formError,
    required this.onSubmit,
  });

  final PurchaseOrder po;
  final GlobalKey<FormState> formKey;
  final TextEditingController receivedBy;
  final TextEditingController note;
  final TextEditingController Function(String) controllerFor;
  final String? formError;
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
          Text(l10n.goodsReceiptFormForPo(po.number),
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(po.vendorName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 16),
          TextFormField(
            controller: receivedBy,
            decoration: InputDecoration(
              labelText: l10n.goodsReceiptReceivedByLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.validatorRequired
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: note,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.goodsReceiptNoteLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.goodsReceiptLinesHeading,
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final line in po.lineItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LineRow(line: line, controller: controllerFor(line.id)),
            ),
          if (formError != null) ...[
            const SizedBox(height: 8),
            Text(
              formError!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.local_shipping_outlined),
            label: Text(l10n.goodsReceiptSubmitAction),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.controller});
  final PurchaseOrderLine line;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final outstanding = line.outstandingQuantity;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.description, style: theme.textTheme.bodyMedium),
            if (line.sku != null)
              Text(line.sku!, style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              l10n.poLineOutstandingLabel(outstanding.toString()),
              style: theme.textTheme.labelSmall?.copyWith(
                color: outstanding == 0
                    ? theme.colorScheme.outline
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              enabled: outstanding > 0,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.goodsReceiptQuantityLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
