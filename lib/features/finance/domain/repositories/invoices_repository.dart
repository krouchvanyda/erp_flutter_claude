import '../entities/invoice.dart';
import '../entities/invoice_detail.dart';

/// Domain contract for invoice access (Slices 3.2.1 / 3.2.2 / 3.2.4).
abstract class InvoicesRepository {
  Future<List<Invoice>> getAll();
  Stream<List<Invoice>> watchAll();
  Future<Invoice?> findById(String id);

  /// Full record — header + line items + totals. `null` when unknown.
  Future<InvoiceDetail?> findDetailById(String id);

  /// Persists an `approved` transition (Slice 3.2.4). Optimistic local
  /// write happens immediately; the data layer also enqueues a sync op
  /// for the eventual `PATCH /invoices/{id}/approve` call.
  ///
  /// Returns the updated [Invoice]. Throws `StateError` when the id is
  /// unknown — caller (the UseCase) pre-validates state transitions so
  /// the repo can stay dumb.
  Future<Invoice> approve({
    required String invoiceId,
    required String approverId,
    required DateTime actionedAt,
  });

  /// Persists a `rejected` transition (Slice 3.2.4). Same contract as
  /// [approve]; the [reason] is captured on the row for the audit log
  /// viewer (Slice 9.3.2).
  Future<Invoice> reject({
    required String invoiceId,
    required String approverId,
    required String reason,
    required DateTime actionedAt,
  });

  /// Submit a `draft` for approval (state machine helper). Used by the
  /// detail page's "Submit for approval" action when the invoice is
  /// still in `draft`. No audit fields written — the submit isn't a
  /// privileged action.
  Future<Invoice> submitForApproval({
    required String invoiceId,
    required DateTime actionedAt,
  });

  /// Re-open a `rejected` invoice back to `draft` (state machine
  /// helper — spec calls this "re-open for revision"). Audit fields are
  /// cleared so the next approve/reject writes fresh.
  Future<Invoice> reopen({
    required String invoiceId,
    required DateTime actionedAt,
  });
}
