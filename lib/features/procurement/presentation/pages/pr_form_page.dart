import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/validators/validators.dart';
import '../../domain/entities/purchase_request.dart';
import '../../domain/repositories/purchase_requests_repository.dart';

/// Create-PR form (Slice 4.1.2).
///
/// **No bloc** — `Form` + per-field controllers + a tiny mutable
/// list of line items. Validation rules reuse `Validators` from
/// Slice 3.2.3 so the contract stays single-source.
class PurchaseRequestFormPage extends StatefulWidget {
  const PurchaseRequestFormPage({super.key});

  @override
  State<PurchaseRequestFormPage> createState() =>
      _PurchaseRequestFormPageState();
}

class _PurchaseRequestFormPageState extends State<PurchaseRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _requester = TextEditingController();
  final _costCenter = TextEditingController();
  final _approver = TextEditingController();
  final _justification = TextEditingController();

  final List<_LineDraft> _lines = [_LineDraft()];

  @override
  void dispose() {
    _requester.dispose();
    _costCenter.dispose();
    _approver.dispose();
    _justification.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  String _resolveError(AppLocalizations l10n, String? code) {
    return switch (code) {
      'required' => l10n.validatorRequired,
      'invalid_number' => l10n.validatorInvalidNumber,
      'must_be_positive' => l10n.validatorMustBePositive,
      _ => '',
    };
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    var subtotal = 0.0;
    final lines = <PurchaseRequestLine>[];
    for (var i = 0; i < _lines.length; i++) {
      final draft = _lines[i];
      final qty = num.parse(draft.quantity.text.trim());
      final price = num.parse(draft.unitPrice.text.trim());
      final lineTotal = qty * price;
      subtotal += lineTotal.toDouble();
      lines.add(PurchaseRequestLine(
        id: 'tmp-li-${i + 1}',
        description: draft.description.text.trim(),
        quantity: qty,
        unitPrice: _money(price),
        lineTotal: _money(lineTotal),
      ));
    }

    final draft = PurchaseRequest(
      id: 'tmp', // overwritten by repo
      number: 'PR-tmp', // overwritten by repo
      requesterName: _requester.text.trim(),
      costCenter: _costCenter.text.trim(),
      approverName: _approver.text.trim(),
      createdAt: DateTime.now().toUtc(),
      status: PurchaseRequestStatus.submitted,
      totalAmount: _money(subtotal),
      lineItems: lines,
      justification: _justification.text.trim().isEmpty
          ? null
          : _justification.text.trim(),
    );

    try {
      await getIt<PurchaseRequestsRepository>().create(draft);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.prFormSavedSnack)));
      if (context.canPop()) context.pop();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.prFormSaveFailed(e.toString()))));
    }
  }

  String _money(num n) {
    final neg = n < 0;
    final abs = n.abs().toStringAsFixed(2);
    final parts = abs.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${neg ? '-' : ''}\$$buf.${parts[1]}';
  }

  void _addLine() => setState(() => _lines.add(_LineDraft()));
  void _removeLine(int i) {
    if (_lines.length == 1) return;
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.prFormCreateTitle),
        actions: [
          IconButton(
            tooltip: l10n.prFormSaveTooltip,
            icon: const Icon(Icons.save_outlined),
            onPressed: _submit,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _requester,
              decoration: InputDecoration(
                labelText: l10n.prFormRequesterLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  _resolveError(l10n, Validators.required(v)).ifEmptyToNull(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costCenter,
                    decoration: InputDecoration(
                      labelText: l10n.prFormCostCenterLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => _resolveError(
                            l10n, Validators.required(v))
                        .ifEmptyToNull(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _approver,
                    decoration: InputDecoration(
                      labelText: l10n.prFormApproverLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => _resolveError(
                            l10n, Validators.required(v))
                        .ifEmptyToNull(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _justification,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.prFormJustificationLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.prFormLinesHeading,
                      style: theme.textTheme.titleSmall),
                ),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.prFormAddLineAction),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < _lines.length; i++) ...[
              _LineEditor(
                key: ValueKey(_lines[i]),
                draft: _lines[i],
                index: i,
                resolveError: (code) => _resolveError(l10n, code),
                onRemove: _lines.length == 1 ? null : () => _removeLine(i),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_outlined),
              label: Text(l10n.prFormSubmitAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineDraft {
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unitPrice = TextEditingController();

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.resolveError,
    required this.onRemove,
  });

  final _LineDraft draft;
  final int index;
  final String Function(String?) resolveError;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.prFormLineHeading(index + 1),
                    style: theme.textTheme.labelLarge),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    tooltip: l10n.prFormRemoveLineTooltip,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                  ),
              ],
            ),
            TextFormField(
              controller: draft.description,
              decoration: InputDecoration(
                labelText: l10n.prFormLineDescriptionLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) =>
                  resolveError(Validators.required(v)).ifEmptyToNull(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.prFormLineQuantityLabel,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        resolveError(Validators.positiveNumber(v))
                            .ifEmptyToNull(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: draft.unitPrice,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.prFormLineUnitPriceLabel,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        resolveError(Validators.positiveNumber(v))
                            .ifEmptyToNull(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String? ifEmptyToNull() => isEmpty ? null : this;
}
