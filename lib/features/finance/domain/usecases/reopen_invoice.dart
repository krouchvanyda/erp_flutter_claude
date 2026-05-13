import '../../../../core/error/failure.dart';
import '../../../../core/utils/clock.dart';
import '../entities/invoice.dart';
import '../repositories/invoices_repository.dart';

/// `rejected → draft` transition (Slice 3.2.4 spec — "re-open for
/// revision"). The originating user fixes whatever the rejector flagged
/// and re-submits.
class ReopenInvoiceUseCase {
  ReopenInvoiceUseCase({
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
    if (invoice.status != InvoiceStatus.rejected) {
      throw Failure.conflict(
        message: 'Only rejected invoices can be re-opened '
            '(was ${invoice.status.name})',
      );
    }
    return _repository.reopen(
      invoiceId: invoiceId,
      actionedAt: _clock(),
    );
  }
}
