import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/validators/validators.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/sales_quotation.dart';
import '../../domain/repositories/customers_repository.dart';
import '../../domain/repositories/quotations_repository.dart';

/// Create-quotation form (Slice 6.2.1).
class QuotationFormPage extends StatefulWidget {
  const QuotationFormPage({super.key});

  @override
  State<QuotationFormPage> createState() => _QuotationFormPageState();
}

class _QuotationFormPageState extends State<QuotationFormPage> {
  final _formKey = GlobalKey<FormState>();
  late Future<List<Customer>> _customersFuture;
  Customer? _customer;
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  final List<_LineDraft> _lines = [_LineDraft()];

  @override
  void initState() {
    super.initState();
    _customersFuture = getIt<CustomersRepository>().getAll();
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  String _resolve(AppLocalizations l10n, String? code) {
    return switch (code) {
      'required' => l10n.validatorRequired,
      'invalid_number' => l10n.validatorInvalidNumber,
      'must_be_positive' => l10n.validatorMustBePositive,
      _ => '',
    };
  }

  String _money(num n) {
    final abs = n.abs().toStringAsFixed(2);
    final parts = abs.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${n < 0 ? '-' : ''}\$$buf.${parts[1]}';
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_customer == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(l10n.salesQuotationPickCustomer)));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    var subtotal = 0.0;
    final lines = <SalesLineItem>[];
    for (var i = 0; i < _lines.length; i++) {
      final draft = _lines[i];
      final qty = num.parse(draft.quantity.text.trim());
      final price = num.parse(draft.unitPrice.text.trim());
      final lineTotal = qty * price;
      subtotal += lineTotal.toDouble();
      lines.add(SalesLineItem(
        id: 'tmp-li-${i + 1}',
        description: draft.description.text.trim(),
        quantity: qty,
        unitPrice: _money(price),
        lineTotal: _money(lineTotal),
      ));
    }

    final draft = SalesQuotation(
      id: 'tmp',
      number: 'QT-tmp',
      customerId: _customer!.id,
      customerName: _customer!.name,
      createdAt: DateTime.now().toUtc(),
      validUntil: _validUntil.toUtc(),
      status: QuotationStatus.draft,
      totalAmount: _money(subtotal),
      lineItems: lines,
    );

    try {
      await getIt<QuotationsRepository>().create(draft);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.salesQuotationSavedSnack)));
      if (context.canPop()) context.pop();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(l10n.salesQuotationSaveFailed(e.toString()))));
    }
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
      appBar: AppBar(title: Text(l10n.salesQuotationNewTitle)),
      body: FutureBuilder<List<Customer>>(
        future: _customersFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final customers = snap.data ?? const <Customer>[];
          return Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<Customer>(
                  initialValue: _customer,
                  decoration: InputDecoration(
                    labelText: l10n.salesQuotationCustomerLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in customers)
                      DropdownMenuItem(value: c, child: Text(c.name)),
                  ],
                  onChanged: (c) => setState(() => _customer = c),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickValidUntil,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.salesQuotationValidUntilField,
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      '${_validUntil.year.toString().padLeft(4, '0')}-'
                      '${_validUntil.month.toString().padLeft(2, '0')}-'
                      '${_validUntil.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(l10n.salesQuotationLinesHeading,
                          style: theme.textTheme.titleSmall),
                    ),
                    TextButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.salesQuotationAddLineAction),
                    ),
                  ],
                ),
                for (var i = 0; i < _lines.length; i++) ...[
                  _LineEditor(
                    key: ValueKey(_lines[i]),
                    draft: _lines[i],
                    index: i,
                    resolve: (c) => _resolve(l10n, c),
                    onRemove:
                        _lines.length == 1 ? null : () => _removeLine(i),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.salesQuotationSaveAction),
                ),
              ],
            ),
          );
        },
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
    required this.resolve,
    required this.onRemove,
  });
  final _LineDraft draft;
  final int index;
  final String Function(String?) resolve;
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
                Text(l10n.salesQuotationLineHeading(index + 1),
                    style: theme.textTheme.labelLarge),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    tooltip: l10n.salesQuotationRemoveLineTooltip,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                  ),
              ],
            ),
            TextFormField(
              controller: draft.description,
              decoration: InputDecoration(
                labelText: l10n.salesQuotationLineDescriptionLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) {
                final code = Validators.required(v);
                if (code == null) return null;
                final m = resolve(code);
                return m.isEmpty ? null : m;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.salesQuotationLineQuantityLabel,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) {
                      final code = Validators.positiveNumber(v);
                      if (code == null) return null;
                      final m = resolve(code);
                      return m.isEmpty ? null : m;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: draft.unitPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.salesQuotationLineUnitPriceLabel,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) {
                      final code = Validators.positiveNumber(v);
                      if (code == null) return null;
                      final m = resolve(code);
                      return m.isEmpty ? null : m;
                    },
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
