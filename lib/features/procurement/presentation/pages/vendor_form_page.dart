import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/validators/validators.dart';
import '../../domain/entities/vendor.dart';
import '../../domain/repositories/vendors_repository.dart';

/// Vendor onboarding form (Slice 4.3.2).
class VendorFormPage extends StatefulWidget {
  const VendorFormPage({super.key});

  @override
  State<VendorFormPage> createState() => _VendorFormPageState();
}

class _VendorFormPageState extends State<VendorFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _taxId = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _contactPerson = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _taxId.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _contactPerson.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _resolveError(AppLocalizations l10n, String? code) {
    return switch (code) {
      'required' => l10n.validatorRequired,
      'invalid_email' => l10n.validatorInvalidEmail,
      _ => '',
    };
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final draft = Vendor(
      id: 'tmp',
      name: _name.text.trim(),
      taxId: _taxId.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      status: VendorStatus.active,
      onboardedAt: DateTime.now().toUtc(),
      contactPerson: _contactPerson.text.trim().isEmpty
          ? null
          : _contactPerson.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    try {
      await getIt<VendorsRepository>().create(draft);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.vendorFormSavedSnack)));
      if (context.canPop()) context.pop();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.vendorFormSaveFailed(e.toString())),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vendorFormTitle),
        actions: [
          IconButton(
            tooltip: l10n.vendorFormSaveTooltip,
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
            _field(_name, l10n.vendorFormNameLabel, Validators.required, l10n),
            const SizedBox(height: 12),
            _field(_taxId, l10n.vendorFormTaxIdLabel, Validators.required, l10n),
            const SizedBox(height: 12),
            _field(_email, l10n.vendorFormEmailLabel, Validators.email, l10n,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_phone, l10n.vendorFormPhoneLabel, Validators.required, l10n,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _field(
              _address,
              l10n.vendorFormAddressLabel,
              Validators.required,
              l10n,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactPerson,
              decoration: InputDecoration(
                labelText: l10n.vendorFormContactPersonLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.vendorFormNotesLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: Text(l10n.vendorFormSaveAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String? Function(String?) rule,
    AppLocalizations l10n, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        final code = rule(v);
        if (code == null) return null;
        final msg = _resolveError(l10n, code);
        return msg.isEmpty ? null : msg;
      },
    );
  }
}
