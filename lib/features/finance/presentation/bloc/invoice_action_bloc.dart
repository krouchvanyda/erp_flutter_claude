import 'package:bloc/bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../auth/domain/permission_gate.dart';
import '../../domain/usecases/approve_invoice.dart';
import '../../domain/usecases/reject_invoice.dart';
import '../../domain/usecases/reopen_invoice.dart';
import '../../domain/usecases/submit_invoice_for_approval.dart';
import 'invoice_action_event.dart';
import 'invoice_action_state.dart';

/// Bloc for invoice approval workflow actions (Slice 3.2.4).
///
/// **Why a single bloc for four events**: approve/reject/submit/reopen
/// share the same `Loading → Success/Failure` shape, and the detail
/// page only needs one of them in flight at a time. Keeping them in
/// one bloc avoids three near-identical class triples.
///
/// **`approverId` is pulled lazily** from [PermissionGate] at
/// event-handle time rather than ctor time so the bloc still works if
/// the snapshot's user changes (e.g. dev impersonation toggle in
/// Storybook). For production this is the signed-in user.
class InvoiceActionBloc extends Bloc<InvoiceActionEvent, InvoiceActionState> {
  InvoiceActionBloc({
    required ApproveInvoiceUseCase approveInvoice,
    required RejectInvoiceUseCase rejectInvoice,
    required SubmitInvoiceForApprovalUseCase submitInvoice,
    required ReopenInvoiceUseCase reopenInvoice,
    required PermissionGate permissions,
  })  : _approve = approveInvoice,
        _reject = rejectInvoice,
        _submit = submitInvoice,
        _reopen = reopenInvoice,
        _permissions = permissions,
        super(const InvoiceActionInitial()) {
    on<InvoiceActionApprove>(_onApprove);
    on<InvoiceActionReject>(_onReject);
    on<InvoiceActionSubmit>(_onSubmit);
    on<InvoiceActionReopen>(_onReopen);
  }

  final ApproveInvoiceUseCase _approve;
  final RejectInvoiceUseCase _reject;
  final SubmitInvoiceForApprovalUseCase _submit;
  final ReopenInvoiceUseCase _reopen;
  final PermissionGate _permissions;

  Future<void> _onApprove(
    InvoiceActionApprove event,
    Emitter<InvoiceActionState> emit,
  ) async {
    emit(const InvoiceActionLoading());
    final approverId = _permissions.currentUserId;
    if (approverId == null) {
      emit(const InvoiceActionFailure(
        Failure.unauthorized(message: 'No signed-in user'),
      ));
      return;
    }
    try {
      final invoice = await _approve(
        invoiceId: event.invoiceId,
        approverId: approverId,
      );
      emit(InvoiceActionSuccess(invoice));
    } on Failure catch (f) {
      emit(InvoiceActionFailure(f));
    } catch (e) {
      emit(InvoiceActionFailure(Failure.unknown(message: e.toString())));
    }
  }

  Future<void> _onReject(
    InvoiceActionReject event,
    Emitter<InvoiceActionState> emit,
  ) async {
    emit(const InvoiceActionLoading());
    final approverId = _permissions.currentUserId;
    if (approverId == null) {
      emit(const InvoiceActionFailure(
        Failure.unauthorized(message: 'No signed-in user'),
      ));
      return;
    }
    try {
      final invoice = await _reject(
        invoiceId: event.invoiceId,
        approverId: approverId,
        reason: event.reason,
      );
      emit(InvoiceActionSuccess(invoice));
    } on Failure catch (f) {
      emit(InvoiceActionFailure(f));
    } catch (e) {
      emit(InvoiceActionFailure(Failure.unknown(message: e.toString())));
    }
  }

  Future<void> _onSubmit(
    InvoiceActionSubmit event,
    Emitter<InvoiceActionState> emit,
  ) async {
    emit(const InvoiceActionLoading());
    try {
      final invoice = await _submit(invoiceId: event.invoiceId);
      emit(InvoiceActionSuccess(invoice));
    } on Failure catch (f) {
      emit(InvoiceActionFailure(f));
    } catch (e) {
      emit(InvoiceActionFailure(Failure.unknown(message: e.toString())));
    }
  }

  Future<void> _onReopen(
    InvoiceActionReopen event,
    Emitter<InvoiceActionState> emit,
  ) async {
    emit(const InvoiceActionLoading());
    try {
      final invoice = await _reopen(invoiceId: event.invoiceId);
      emit(InvoiceActionSuccess(invoice));
    } on Failure catch (f) {
      emit(InvoiceActionFailure(f));
    } catch (e) {
      emit(InvoiceActionFailure(Failure.unknown(message: e.toString())));
    }
  }
}
