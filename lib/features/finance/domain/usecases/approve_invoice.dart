import '../../../../core/error/failure.dart';
import '../../../../core/utils/clock.dart';
import '../../../auth/domain/entities/permission.dart';
import '../../../auth/domain/permission_gate.dart';
import '../entities/invoice.dart';
import '../repositories/invoices_repository.dart';

/// Permission token required to approve an invoice (Slice 3.2.4 spec).
const kFinanceApprovePermission = 'finance.approve';

/// Approve an invoice (Slice 3.2.4).
///
/// **Invariants** (all enforced here — never trust the UI):
///   1. Signed-in user holds [`finance.approve`] permission.
///   2. Invoice exists.
///   3. Current status is [`InvoiceStatus.pendingApproval`] — approving
///      a `draft`/`approved`/`rejected` is a no-double-action guard.
///
/// **Failures** (all thrown as [`Failure`]):
///   - [`ForbiddenFailure`] — permission missing.
///   - [`NotFoundFailure`] — id unknown.
///   - [`ConflictFailure`] — wrong status. This is the spec's
///     "InvalidStateFailure" surfaced via the existing `conflict`
///     variant so we don't have to extend the sealed [`Failure`]
///     union (and re-run build_runner) for a single use site.
class ApproveInvoiceUseCase {
  ApproveInvoiceUseCase({
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
  }) async {
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
            'Cannot approve an invoice in status ${invoice.status.name}',
      );
    }
    return _repository.approve(
      invoiceId: invoiceId,
      approverId: approverId,
      actionedAt: _clock(),
    );
  }
}
