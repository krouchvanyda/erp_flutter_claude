import 'dart:convert';

import '../../../../core/database/sync_queue_dao.dart';
import '../../../../core/sync/sync_op_type.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_detail.dart';
import '../../domain/entities/invoice_line_item.dart';
import '../../domain/repositories/invoices_repository.dart';
import '../datasources/invoices_dao.dart';
import '../invoice_seed.dart';

/// Drift-backed [`InvoicesRepository`] (Slice 3.2.4) — replaces the
/// in-memory stub with a persistent cache that survives restart and
/// works offline.
///
/// **Lazy seed**: on first call, if `cached_invoices` is empty, the
/// bootstrap writes [`InvoiceSeed.headers`] + the detail seed. Same
/// pattern as [`DriftAccountsRepository`].
///
/// **SyncQueue integration**: every approve/reject also enqueues a
/// sync op via the injected [`SyncQueueDao`]. The queue is the real
/// thing now (drift-backed), so the SyncEngine retry path can later
/// replay these against `PATCH /invoices/{id}/approve` when the
/// backend lands.
///
/// **Optimistic update** (per spec): the local drift write completes
/// before [approve] / [reject] return. If a later sync attempt fails,
/// the SyncEngine's dead-letter path surfaces it; the UI sees the
/// new status immediately.
class DriftInvoicesRepository implements InvoicesRepository {
  DriftInvoicesRepository({
    required InvoicesDao dao,
    required SyncQueueDao syncQueue,
  })  : _dao = dao,
        _syncQueue = syncQueue;

  final InvoicesDao _dao;
  final SyncQueueDao _syncQueue;
  Future<void>? _bootstrap;

  Future<void> _ensureBootstrapped() {
    return _bootstrap ??= _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    final count = await _dao.countInvoices();
    if (count > 0) return;
    final detailSeed = InvoiceSeed.details();
    for (final header in InvoiceSeed.headers) {
      await _dao.upsertWithDetail(
        header: header,
        detail: detailSeed[header.id],
      );
    }
  }

  @override
  Future<List<Invoice>> getAll() async {
    await _ensureBootstrapped();
    return _dao.getAllInvoices();
  }

  @override
  Stream<List<Invoice>> watchAll() async* {
    await _ensureBootstrapped();
    yield* _dao.watchAllInvoices();
  }

  @override
  Future<Invoice?> findById(String id) async {
    await _ensureBootstrapped();
    return _dao.findInvoiceById(id);
  }

  @override
  Future<InvoiceDetail?> findDetailById(String id) async {
    await _ensureBootstrapped();
    final detail = await _dao.findDetailById(id);
    if (detail == null) return null;
    // Cached headers without lines fall back to a single synthetic
    // line so the detail page still has *something* to render (mirrors
    // the stub's behavior for inv-016/017/018/013).
    if (detail.lineItems.isNotEmpty) return detail;
    return InvoiceDetail(
      header: detail.header,
      subtotal: detail.header.totalAmount,
      tax: r'$0.00',
      lineItems: [
        InvoiceLineItem(
          id: 'li-${detail.header.id}',
          description: detail.header.invoiceNumber,
          quantity: 1,
          unitPrice: detail.header.totalAmount,
          lineTotal: detail.header.totalAmount,
        ),
      ],
    );
  }

  @override
  Future<Invoice> approve({
    required String invoiceId,
    required String approverId,
    required DateTime actionedAt,
  }) async {
    await _ensureBootstrapped();
    final updated = await _dao.approve(
      invoiceId: invoiceId,
      approverId: approverId,
      actionedAt: actionedAt,
    );
    await _enqueueSyncOp(
      invoiceId: invoiceId,
      endpointPath: '/invoices/$invoiceId/approve',
      payload: {'approver_id': approverId},
    );
    return updated;
  }

  @override
  Future<Invoice> reject({
    required String invoiceId,
    required String approverId,
    required String reason,
    required DateTime actionedAt,
  }) async {
    await _ensureBootstrapped();
    final updated = await _dao.reject(
      invoiceId: invoiceId,
      approverId: approverId,
      reason: reason,
      actionedAt: actionedAt,
    );
    await _enqueueSyncOp(
      invoiceId: invoiceId,
      endpointPath: '/invoices/$invoiceId/reject',
      payload: {'approver_id': approverId, 'reason': reason},
    );
    return updated;
  }

  @override
  Future<Invoice> submitForApproval({
    required String invoiceId,
    required DateTime actionedAt,
  }) async {
    await _ensureBootstrapped();
    return _dao.submitForApproval(
      invoiceId: invoiceId,
      actionedAt: actionedAt,
    );
  }

  @override
  Future<Invoice> reopen({
    required String invoiceId,
    required DateTime actionedAt,
  }) async {
    await _ensureBootstrapped();
    return _dao.reopen(invoiceId: invoiceId, actionedAt: actionedAt);
  }

  // ── Helpers ──────────────────────────────────────────────────

  Future<void> _enqueueSyncOp({
    required String invoiceId,
    required String endpointPath,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _syncQueue.enqueue(
        entityType: 'invoice',
        entityId: invoiceId,
        operation: SyncOpType.update,
        payloadJson: jsonEncode(payload),
        endpointMethod: 'PATCH',
        endpointPath: endpointPath,
      );
    } catch (_) {
      // Best-effort — the local write already happened, the engine's
      // retry path owns recovery. Don't surface enqueue errors to the
      // user.
    }
  }
}
