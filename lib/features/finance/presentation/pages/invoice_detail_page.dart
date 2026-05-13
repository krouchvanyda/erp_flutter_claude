import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/permission_guard.dart';
import '../../../auth/domain/entities/permission.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_detail.dart';
import '../../domain/entities/invoice_line_item.dart';
import '../../domain/repositories/invoices_repository.dart';
import '../../domain/usecases/approve_invoice.dart';
import '../bloc/invoice_action_bloc.dart';
import '../bloc/invoice_action_event.dart';
import '../bloc/invoice_action_state.dart';
import '../widgets/approve_invoice_bottom_sheet.dart';
import '../widgets/reject_invoice_bottom_sheet.dart';
import 'invoice_list_page.dart' show invoiceStatusColor, invoiceStatusLabel;

/// Invoice detail page (Slice 3.2.2 + Slice 3.2.4).
///
/// **Slice 3.2.4 wiring**:
/// - Approve/Reject actions go through [`InvoiceActionBloc`] → use case
///   layer → repository (which enqueues to SyncQueue).
/// - Buttons wrapped in [`PermissionGuard`] checking `finance.approve`.
/// - Per-status visibility:
///   - `draft` → "Submit for approval" only.
///   - `pendingApproval` → Approve + Reject enabled.
///   - `approved`/`rejected` → both Approve + Reject visible but
///     **disabled** (spec: "status chip acts as visual lock").
///   - `rejected` also exposes a "Re-open for revision" button.
///
/// **Refresh on success**: the page subscribes to the bloc's stream;
/// any `InvoiceActionSuccess` re-fetches detail so the chip + audit
/// metadata reflect the new state immediately.
class InvoiceDetailPage extends StatelessWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InvoiceActionBloc>(
      create: (_) => getIt<InvoiceActionBloc>(),
      child: _DetailView(invoiceId: invoiceId),
    );
  }
}

class _DetailView extends StatefulWidget {
  const _DetailView({required this.invoiceId});
  final String invoiceId;

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  late InvoicesRepository _repo;
  late Future<InvoiceDetail?> _future;

  @override
  void initState() {
    super.initState();
    _repo = getIt<InvoicesRepository>();
    _future = _repo.findDetailById(widget.invoiceId);
  }

  void _reload() {
    setState(() {
      _future = _repo.findDetailById(widget.invoiceId);
    });
  }

  String _failureMessage(AppLocalizations l10n, Failure f) {
    return switch (f) {
      ForbiddenFailure() => l10n.invoiceActionForbidden,
      NotFoundFailure() => l10n.invoiceActionNotFound,
      ConflictFailure() => l10n.invoiceActionInvalidState,
      UnauthorizedFailure() => l10n.invoiceActionUnauthorized,
      ValidationFailure() => l10n.invoiceRejectReasonRequired,
      _ => l10n.invoiceActionGenericError(
          f.toString(),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<InvoiceActionBloc, InvoiceActionState>(
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        switch (state) {
          case InvoiceActionSuccess(:final invoice):
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(l10n.invoiceActionSuccess(
                  invoiceStatusLabel(l10n, invoice.status),
                )),
              ));
            _reload();
          case InvoiceActionFailure(:final failure):
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(_failureMessage(l10n, failure)),
              ));
          case InvoiceActionLoading() || InvoiceActionInitial():
            break;
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.invoiceDetailTitle)),
        body: FutureBuilder<InvoiceDetail?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _CenteredMessage(
                text: l10n.invoiceDetailError(snap.error.toString()),
              );
            }
            final detail = snap.data;
            if (detail == null) {
              return _CenteredMessage(
                text: l10n.invoiceDetailNotFound(widget.invoiceId),
              );
            }
            return _DetailBody(detail: detail);
          },
        ),
        bottomNavigationBar: FutureBuilder<InvoiceDetail?>(
          future: _future,
          builder: (context, snap) {
            final header = snap.data?.header;
            if (header == null) return const SizedBox.shrink();
            return SafeArea(
              child: _ActionBar(invoice: header),
            );
          },
        ),
      ),
    );
  }
}

/// Status-aware bottom action bar (Slice 3.2.4).
///
/// **Visibility rules**:
/// - `draft`           → Submit only.
/// - `pendingApproval` → Reject + Approve (both gated on `finance.approve`).
/// - `approved`        → Approve+Reject shown but disabled (visual lock).
/// - `rejected`        → Re-open button + disabled Approve/Reject.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.invoice});
  final Invoice invoice;

  Future<void> _onApprove(BuildContext context) async {
    final ok = await ApproveInvoiceBottomSheet.show(context, invoice);
    if (ok != true || !context.mounted) return;
    context.read<InvoiceActionBloc>().add(InvoiceActionApprove(invoice.id));
  }

  Future<void> _onReject(BuildContext context) async {
    final reason = await RejectInvoiceBottomSheet.show(context, invoice);
    if (reason == null || !context.mounted) return;
    context.read<InvoiceActionBloc>().add(
          InvoiceActionReject(invoiceId: invoice.id, reason: reason),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<InvoiceActionBloc, InvoiceActionState>(
      builder: (context, actionState) {
        final isLoading = actionState is InvoiceActionLoading;
        switch (invoice.status) {
          case InvoiceStatus.draft:
            return _SingleAction(
              icon: Icons.send_outlined,
              label: l10n.invoiceSubmitAction,
              onPressed: isLoading
                  ? null
                  : () => context
                      .read<InvoiceActionBloc>()
                      .add(InvoiceActionSubmit(invoice.id)),
            );
          case InvoiceStatus.pendingApproval:
            return _ApproveRejectPair(
              invoice: invoice,
              onApprove: isLoading ? null : () => _onApprove(context),
              onReject: isLoading ? null : () => _onReject(context),
            );
          case InvoiceStatus.approved:
            return _ApproveRejectPair(
              invoice: invoice,
              onApprove: null,
              onReject: null,
            );
          case InvoiceStatus.rejected:
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  _ApproveRejectPair(
                    invoice: invoice,
                    onApprove: null,
                    onReject: null,
                    insetPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => context
                              .read<InvoiceActionBloc>()
                              .add(InvoiceActionReopen(invoice.id)),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.invoiceReopenAction),
                    ),
                  ),
                ],
              ),
            );
        }
      },
    );
  }
}

class _SingleAction extends StatelessWidget {
  const _SingleAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

/// Approve + Reject pair, both wrapped in `PermissionGuard` so the
/// signed-in user has to hold `finance.approve` to see them enabled.
/// `onApprove == null` / `onReject == null` disables the buttons even
/// when the user has the permission (used to render the "visual lock"
/// once status is terminal).
class _ApproveRejectPair extends StatelessWidget {
  const _ApproveRejectPair({
    required this.invoice,
    required this.onApprove,
    required this.onReject,
    this.insetPadding = const EdgeInsets.fromLTRB(16, 8, 16, 12),
  });

  final Invoice invoice;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final EdgeInsetsGeometry insetPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: insetPadding,
      child: PermissionGuard.builder(
        required: const Permission(token: kFinanceApprovePermission),
        builder: (context, allowed) {
          // Both layers of defence (per spec guardrails):
          // 1. PermissionGuard widget hides/disables visually.
          // 2. UseCase re-checks permission at dispatch time.
          // If not allowed, render disabled buttons so the user can see
          // the action exists but is locked.
          final approveEnabled = allowed && onApprove != null;
          final rejectEnabled = allowed && onReject != null;
          return Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: rejectEnabled ? onReject : null,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.invoiceRejectAction),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: approveEnabled ? onApprove : null,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.invoiceApproveAction),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});
  final InvoiceDetail detail;

  static final _date = DateFormat('yyyy-MM-dd');
  static final _stamp = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final h = detail.header;
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
                      child: Text(h.invoiceNumber,
                          style: theme.textTheme.titleLarge),
                    ),
                    _StatusBadge(status: h.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(h.customerName, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                      label: l10n.invoiceDetailIssuedLabel,
                      value: _date.format(h.issuedAt.toLocal()),
                    ),
                    _MetaChip(
                      label: l10n.invoiceDetailDueLabel,
                      value: _date.format(h.dueAt.toLocal()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (h.actionedAt != null) ...[
          const SizedBox(height: 12),
          _AuditCard(invoice: h, stampFmt: _stamp),
        ],
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.invoiceDetailLinesHeading,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final line in detail.lineItems) _LineRow(line: line),
              const Divider(height: 0),
              _TotalRow(
                  label: l10n.invoiceDetailSubtotalLabel,
                  value: detail.subtotal),
              _TotalRow(
                  label: l10n.invoiceDetailTaxLabel, value: detail.tax),
              _TotalRow(
                label: l10n.invoiceDetailTotalLabel,
                value: h.totalAmount,
                emphasised: true,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (detail.notes != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.invoiceDetailNotesHeading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(detail.notes!),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        // PDF preview placeholder — Slice 3.2.2 documents the seam;
        // a real renderer (pdfx / printing) is gated on backend PDFs.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.invoiceDetailPdfHeading,
                        style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l10n.invoiceDetailPdfPlaceholder,
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Slice 3.2.4 audit trail card — surfaces `approved_by` / `rejected_by`,
/// `rejected_reason`, and `actioned_at` for the audit log viewer
/// (Slice 9.3.2) preview.
class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.invoice, required this.stampFmt});
  final Invoice invoice;
  final DateFormat stampFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isReject = invoice.status == InvoiceStatus.rejected;
    final actorId = invoice.approvedBy ?? invoice.rejectedBy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isReject ? Icons.cancel_outlined : Icons.verified_outlined,
                  size: 18,
                  color: invoiceStatusColor(theme, invoice.status),
                ),
                const SizedBox(width: 8),
                Text(
                  isReject
                      ? l10n.invoiceAuditRejectedHeading
                      : l10n.invoiceAuditApprovedHeading,
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (actorId != null)
              Text(
                l10n.invoiceAuditActorLine(actorId),
                style: theme.textTheme.bodySmall,
              ),
            Text(
              l10n.invoiceAuditWhenLine(
                stampFmt.format(invoice.actionedAt!.toLocal()),
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (isReject && invoice.rejectedReason != null) ...[
              const SizedBox(height: 6),
              Text(
                l10n.invoiceAuditReasonLine(invoice.rejectedReason!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = invoiceStatusColor(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        invoiceStatusLabel(l10n, status),
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
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
        Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final InvoiceLineItem line;

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
          Text(
            '${line.quantity} × ${line.unitPrice}',
            style: theme.textTheme.labelSmall,
          ),
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

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = (emphasised
            ? theme.textTheme.titleMedium
            : theme.textTheme.bodyMedium)
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
