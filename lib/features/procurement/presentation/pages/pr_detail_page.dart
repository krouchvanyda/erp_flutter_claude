import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/purchase_request.dart';
import '../../domain/entities/vendor.dart';
import '../../domain/repositories/purchase_orders_repository.dart';
import '../../domain/repositories/purchase_requests_repository.dart';
import '../../domain/repositories/vendors_repository.dart';
import '../../domain/usecases/convert_pr_to_po.dart';
import '../../domain/usecases/pr_approval.dart';
import 'pr_list_page.dart' show PurchaseRequestStatusBadge, prStatusLabel;

/// PR detail page (Slice 4.1.3) — header card, line table, totals,
/// action bar with Approve / Reject (when submitted) or Submit (when
/// draft). Reject opens a reason dialog reused in spirit from the
/// invoice approval flow.
class PurchaseRequestDetailPage extends StatefulWidget {
  const PurchaseRequestDetailPage({super.key, required this.prId});

  final String prId;

  @override
  State<PurchaseRequestDetailPage> createState() =>
      _PurchaseRequestDetailPageState();
}

class _PurchaseRequestDetailPageState
    extends State<PurchaseRequestDetailPage> {
  late PurchaseRequestsRepository _repo;
  late Future<PurchaseRequest?> _future;
  final _approval = const PurchaseRequestApprovalUseCase();

  @override
  void initState() {
    super.initState();
    _repo = getIt<PurchaseRequestsRepository>();
    _future = _repo.findById(widget.prId);
  }

  void _reload() {
    setState(() {
      _future = _repo.findById(widget.prId);
    });
  }

  Future<void> _onApprove(PurchaseRequest pr) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = _approval.approve(pr);
    if (outcome.result ==
        PurchaseRequestApprovalResult.notAllowedFromCurrentStatus) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.prApprovalNotAllowed(
            l10n.prApproveAction.toLowerCase(),
          )),
        ));
      return;
    }
    try {
      await _repo.setStatus(pr.id, outcome.pr.status);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
              l10n.prApprovedSnack(prStatusLabel(l10n, outcome.pr.status))),
        ));
      _reload();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.prApprovalFailed(e.toString())),
        ));
    }
  }

  Future<void> _onSubmit(PurchaseRequest pr) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = _approval.submit(pr);
    if (outcome.result !=
        PurchaseRequestApprovalResult.ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.prApprovalNotAllowed(
            l10n.prSubmitAction.toLowerCase(),
          )),
        ));
      return;
    }
    try {
      await _repo.setStatus(pr.id, outcome.pr.status);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.prSubmittedSnack)));
      _reload();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.prApprovalFailed(e.toString())),
        ));
    }
  }

  Future<void> _onConvert(PurchaseRequest pr) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final vendors = await getIt<VendorsRepository>().getAll();
    if (!mounted) return;
    final activeVendors =
        vendors.where((v) => v.status == VendorStatus.active).toList();
    final picked = await showDialog<_ConvertChoice>(
      context: context,
      builder: (_) => _ConvertDialog(vendors: activeVendors),
    );
    if (!mounted || picked == null) return;
    final outcome = convertPurchaseRequestToOrder(
      pr,
      vendorId: picked.vendor.id,
      vendorName: picked.vendor.name,
      expectedAt: picked.expectedAt,
    );
    if (outcome.result != ConvertPurchaseRequestResult.ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.prApprovalNotAllowed(
            l10n.prConvertAction.toLowerCase(),
          )),
        ));
      return;
    }
    try {
      await getIt<PurchaseOrdersRepository>().create(outcome.draftPo!);
      await _repo.setStatus(pr.id, outcome.updatedPr!.status);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.prConvertedSnack)));
      _reload();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.prApprovalFailed(e.toString())),
        ));
    }
  }

  Future<void> _onReject(PurchaseRequest pr) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectReasonDialog(),
    );
    if (!mounted || reason == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = _approval.reject(pr, reason: reason);
    switch (outcome.result) {
      case PurchaseRequestApprovalResult.reasonRequired:
        return;
      case PurchaseRequestApprovalResult.notAllowedFromCurrentStatus:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(l10n.prApprovalNotAllowed(
              l10n.prRejectAction.toLowerCase(),
            )),
          ));
        return;
      case PurchaseRequestApprovalResult.ok:
        try {
          await _repo.setStatus(pr.id, outcome.pr.status);
          if (!mounted) return;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
                SnackBar(content: Text(l10n.prRejectedSnack)));
          _reload();
        } catch (e) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(l10n.prApprovalFailed(e.toString())),
            ));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.prDetailTitle)),
      body: FutureBuilder<PurchaseRequest?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _CenteredMessage(
                text: l10n.prDetailError(snap.error.toString()));
          }
          final pr = snap.data;
          if (pr == null) {
            return _CenteredMessage(
                text: l10n.prDetailNotFound(widget.prId));
          }
          return _DetailBody(pr: pr);
        },
      ),
      bottomNavigationBar: FutureBuilder<PurchaseRequest?>(
        future: _future,
        builder: (context, snap) {
          final pr = snap.data;
          if (pr == null) return const SizedBox.shrink();
          return SafeArea(child: _ActionBar(pr: pr,
            onApprove: () => _onApprove(pr),
            onReject: () => _onReject(pr),
            onSubmit: () => _onSubmit(pr),
            onConvert: () => _onConvert(pr),
          ));
        },
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.pr,
    required this.onApprove,
    required this.onReject,
    required this.onSubmit,
    required this.onConvert,
  });

  final PurchaseRequest pr;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSubmit;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (pr.status == PurchaseRequestStatus.draft) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.send_outlined),
          label: Text(l10n.prSubmitAction),
        ),
      );
    }
    if (pr.status == PurchaseRequestStatus.submitted) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close),
                label: Text(l10n.prRejectAction),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check),
                label: Text(l10n.prApproveAction),
              ),
            ),
          ],
        ),
      );
    }
    if (pr.status == PurchaseRequestStatus.approved) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: onConvert,
          icon: const Icon(Icons.shopping_bag_outlined),
          label: Text(l10n.prConvertAction),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ConvertChoice {
  const _ConvertChoice({required this.vendor, required this.expectedAt});
  final Vendor vendor;
  final DateTime expectedAt;
}

class _ConvertDialog extends StatefulWidget {
  const _ConvertDialog({required this.vendors});
  final List<Vendor> vendors;

  @override
  State<_ConvertDialog> createState() => _ConvertDialogState();
}

class _ConvertDialogState extends State<_ConvertDialog> {
  Vendor? _vendor;
  DateTime _expectedAt = DateTime.now().add(const Duration(days: 14));
  String? _vendorError;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expectedAt = picked);
  }

  void _confirm() {
    if (_vendor == null) {
      setState(() => _vendorError =
          AppLocalizations.of(context).prConvertVendorRequired);
      return;
    }
    Navigator.of(context).pop(
      _ConvertChoice(vendor: _vendor!, expectedAt: _expectedAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFmt = DateFormat('yyyy-MM-dd');
    return AlertDialog(
      title: Text(l10n.prConvertDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<Vendor>(
            initialValue: _vendor,
            decoration: InputDecoration(
              labelText: l10n.prConvertVendorLabel,
              border: const OutlineInputBorder(),
              errorText: _vendorError,
            ),
            items: [
              for (final v in widget.vendors)
                DropdownMenuItem(value: v, child: Text(v.name)),
            ],
            onChanged: (v) => setState(() {
              _vendor = v;
              _vendorError = null;
            }),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.prConvertExpectedLabel,
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(dateFmt.format(_expectedAt)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.prConvertCancel),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(l10n.prConvertConfirm),
        ),
      ],
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.pr});
  final PurchaseRequest pr;
  static final _date = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                      child: Text(pr.number,
                          style: theme.textTheme.titleLarge),
                    ),
                    PurchaseRequestStatusBadge(status: pr.status),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                        label: l10n.prDetailRequesterLabel,
                        value: pr.requesterName),
                    _MetaChip(
                        label: l10n.prDetailCostCenterLabel,
                        value: pr.costCenter),
                    _MetaChip(
                        label: l10n.prDetailApproverLabel,
                        value: pr.approverName),
                    _MetaChip(
                      label: l10n.prDetailCreatedLabel,
                      value: _date.format(pr.createdAt.toLocal()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (pr.justification != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.prDetailJustificationHeading,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 6),
                  Text(pr.justification!),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(l10n.prDetailLinesHeading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ),
              for (final line in pr.lineItems) _LineRow(line: line),
              const Divider(height: 0),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(l10n.prDetailTotalLabel,
                        style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      pr.totalAmount,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final PurchaseRequestLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(line.description),
      subtitle: line.sku == null ? null : Text(line.sku!),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${line.quantity} × ${line.unitPrice}',
              style: theme.textTheme.labelSmall),
          Text(
            line.lineTotal,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();
  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.prRejectDialogTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.prRejectReasonLabel,
            hintText: l10n.prRejectReasonHint,
            border: const OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? l10n.prRejectReasonRequired
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.prRejectCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: Text(l10n.prRejectConfirm),
        ),
      ],
    );
  }
}
