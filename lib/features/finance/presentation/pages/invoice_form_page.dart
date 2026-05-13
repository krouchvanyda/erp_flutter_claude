import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/validators/validators.dart';

/// Create / edit invoice form (Slice 3.2.3).
///
/// **No bloc** — `Form` + per-field controllers is enough for a
/// straightforward submit-once form. The pure validation rules live
/// in [`Validators`] so the field logic is unit-tested separately.
///
/// **No persistence yet** — the submit handler currently pops with a
/// SnackBar success. Wire to `InvoicesRepository.upsert` when the
/// repository grows write methods (out of scope here; would also need
/// the drift cache from 3.1.3 extended to invoices).
class InvoiceFormPage extends StatefulWidget {
  const InvoiceFormPage({super.key, this.invoiceId});

  /// `null` → "create new"; non-null → "edit existing" (the loader
  /// would prefill the form). Edit mode is wired but not preloaded
  /// in this slice.
  final String? invoiceId;

  @override
  State<InvoiceFormPage> createState() => _InvoiceFormPageState();
}

class _InvoiceFormPageState extends State<InvoiceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _customer = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unitPrice = TextEditingController();

  DateTime? _issued = DateTime.now();
  DateTime? _due = DateTime.now().add(const Duration(days: 30));
  String? _dateRangeError;

  bool get _isEdit => widget.invoiceId != null;

  @override
  void dispose() {
    _customer.dispose();
    _description.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  String _resolveError(AppLocalizations l10n, String? code) {
    return switch (code) {
      'required' => l10n.validatorRequired,
      'invalid_number' => l10n.validatorInvalidNumber,
      'must_be_positive' => l10n.validatorMustBePositive,
      'must_be_non_negative' => l10n.validatorMustBeNonNegative,
      'due_before_issued' => l10n.validatorDueBeforeIssued,
      _ => '',
    };
  }

  Future<void> _pickDate(BuildContext context, bool isIssued) async {
    final initial = (isIssued ? _issued : _due) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isIssued) {
        _issued = picked;
      } else {
        _due = picked;
      }
      _dateRangeError = Validators.dueOnOrAfterIssued(
        issued: _issued,
        due: _due,
      );
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final dateErr = Validators.dueOnOrAfterIssued(
      issued: _issued,
      due: _due,
    );
    setState(() => _dateRangeError = dateErr);
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || dateErr != null) return;

    // Persistence wiring deferred (see class doc); confirm the form
    // round-tripped via SnackBar so the UX path is end-to-end demoable.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.invoiceFormSavedSnack)));
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dateFmt = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit
            ? l10n.invoiceFormEditTitle
            : l10n.invoiceFormCreateTitle),
        actions: [
          IconButton(
            tooltip: l10n.invoiceFormSaveTooltip,
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
              controller: _customer,
              decoration: InputDecoration(
                labelText: l10n.invoiceFormCustomerLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  _resolveError(l10n, Validators.required(v))
                      .ifEmptyToNull(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: l10n.invoiceFormIssuedLabel,
                    value: _issued,
                    formatter: dateFmt,
                    onTap: () => _pickDate(context, true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: l10n.invoiceFormDueLabel,
                    value: _due,
                    formatter: dateFmt,
                    onTap: () => _pickDate(context, false),
                  ),
                ),
              ],
            ),
            if (_dateRangeError != null) ...[
              const SizedBox(height: 4),
              Text(
                _resolveError(l10n, _dateRangeError),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            Text(l10n.invoiceFormLineHeading,
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              decoration: InputDecoration(
                labelText: l10n.invoiceFormLineDescriptionLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  _resolveError(l10n, Validators.required(v))
                      .ifEmptyToNull(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.invoiceFormLineQuantityLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => _resolveError(
                            l10n, Validators.positiveNumber(v))
                        .ifEmptyToNull(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitPrice,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.invoiceFormLineUnitPriceLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => _resolveError(
                            l10n, Validators.positiveNumber(v))
                        .ifEmptyToNull(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: Text(l10n.invoiceFormSaveAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          value == null ? '' : formatter.format(value!.toLocal()),
        ),
      ),
    );
  }
}

extension on String {
  /// Form fields treat empty error strings as "valid" — but our
  /// `_resolveError` returns `''` for the no-error path. Convert to
  /// `null` so `validator:` semantics line up.
  String? ifEmptyToNull() => isEmpty ? null : this;
}
