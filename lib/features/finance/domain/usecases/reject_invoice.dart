import '../../../../core/error/failure.dart';
import '../../../../core/utils/clock.dart';
import '../../../auth/domain/entities/permission.dart';
import '../../../auth/domain/permission_gate.dart';
import '../entities/invoice.dart';
import '../repositories/invoices_repository.dart';
import 'approve_invoice.dart' show kFinanceApprovePermission;

/// Reject an invoice with a mandatory reason (Slice 3.2.4).
///
/// **Invariants**:
///   1. Signed-in user holds [`finance.approve`] permission (same gate
///      as approve — the spec deliberately bundles both verbs under one
///      scope so an approver can also reject).
///   2. Invoice exists.
///   3. Current status is [`InvoiceStatus.pendingApproval`].
///   4. [reason] is non-empty after trimming. The form validates this
///      first, but the UseCase re-checks so the rule lives at the
///      domain boundary (spec: "mandatory at domain level").
class RejectInvoiceUseCase {
  RejectInvoiceUseCase({
    required InvoicesRepository repository,
    required PermissionGate permissions,
    Clock? clock,
  })  : _repository = repository,
        _permissions = permissions,
        _clock = clock ?? DateTime.now;

  final InvoicesRepository _repository;
  final PermissionGate _permissions;
  final Clock _clock;

  Future<Invoice> call({
    required String invoiceId,
    required String approverId,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw const Failure.validation(
        fieldErrors: {
          'reason': ['required'],
        },
        message: 'Rejection reason is required',
      );
    }
    if (!_permissions.holds(const Permission(token: kFinanceApprovePermission))) {
      throw const Failure.forbidden(
        message: '$kFinanceApprovePermission required',
      );
    }
    final invoice = await _repository.findById(invoiceId);
    if (invoice == null) {
      throw Failure.notFound(message: 'invoice $invoiceId');
    }
    if (invoice.status != InvoiceStatus.pendingApproval) {
      throw Failure.conflict(
        message:
            'Cannot reject an invoice in status ${invoice.status.name}',
      );
    }
    return _repository.reject(
      invoiceId: invoiceId,
      approverId: approverId,
      reason: trimmedReason,
      actionedAt: _clock(),
    );
  }
}
