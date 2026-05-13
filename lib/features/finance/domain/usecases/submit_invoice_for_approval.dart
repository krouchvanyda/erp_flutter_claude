import '../../../../core/error/failure.dart';
import '../../../../core/utils/clock.dart';
import '../entities/invoice.dart';
import '../repositories/invoices_repository.dart';

/// `draft → pendingApproval` transition (Slice 3.2.4 state machine).
///
/// **No permission gate** — anyone who can edit a draft can also submit
/// it. The privileged step is the approve/reject decision, not the
/// submission.
class SubmitInvoiceForApprovalUseCase {
  SubmitInvoiceForApprovalUseCase({
    required InvoicesRepository repository,
    Clock? clock,
  })  : _repository = repository,
        _clock = clock ?? DateTime.now;

  final InvoicesRepository _repository;
  final Clock _clock;

  Future<Invoice> call({required String invoiceId}) async {
    final invoice = await _repository.findById(invoiceId);
    if (invoice == null) {
      throw Failure.notFound(message: 'invoice $invoiceId');
    }
    if (invoice.status != InvoiceStatus.draft) {
      throw Failure.conflict(
        message:
            'Only draft invoices can be submitted (was ${invoice.status.name})',
      );
    }
    return _repository.submitForApproval(
      invoiceId: invoiceId,
      actionedAt: _clock(),
    );
  }
}
