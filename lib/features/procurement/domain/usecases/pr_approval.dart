import '../entities/purchase_request.dart';

/// Result of an attempted approve / reject (Slice 4.1.3). Mirrors the
/// shape of `InvoiceApprovalResult` so the UI layer can reuse the same
/// snackbar/dialog patterns.
enum PurchaseRequestApprovalResult {
  ok,
  notAllowedFromCurrentStatus,
  reasonRequired,
}

/// Pure-Dart workflow for PR approve / reject (Slice 4.1.3).
///
/// **Status transitions**:
/// - `submitted → approved` on approve
/// - `submitted → rejected` on reject
/// - `draft     → submitted` on `submit` (the form path uses this when
///   it wants an explicit transition rather than creating-as-submitted)
/// - everything else → `notAllowedFromCurrentStatus`
///
/// Reject also requires a non-empty `reason`. The use case returns a
/// result enum + the (possibly unchanged) `PurchaseRequest`; the
/// caller persists the new state via the repository.
class PurchaseRequestApprovalUseCase {
  const PurchaseRequestApprovalUseCase();

  ({PurchaseRequestApprovalResult result, PurchaseRequest pr}) approve(
    PurchaseRequest p,
  ) {
    if (p.status != PurchaseRequestStatus.submitted) {
      return (
        result: PurchaseRequestApprovalResult.notAllowedFromCurrentStatus,
        pr: p,
      );
    }
    return (
      result: PurchaseRequestApprovalResult.ok,
      pr: p.copyWith(status: PurchaseRequestStatus.approved),
    );
  }

  ({PurchaseRequestApprovalResult result, PurchaseRequest pr}) reject(
    PurchaseRequest p, {
    required String reason,
  }) {
    if (reason.trim().isEmpty) {
      return (result: PurchaseRequestApprovalResult.reasonRequired, pr: p);
    }
    if (p.status != PurchaseRequestStatus.submitted) {
      return (
        result: PurchaseRequestApprovalResult.notAllowedFromCurrentStatus,
        pr: p,
      );
    }
    return (
      result: PurchaseRequestApprovalResult.ok,
      pr: p.copyWith(status: PurchaseRequestStatus.rejected),
    );
  }

  ({PurchaseRequestApprovalResult result, PurchaseRequest pr}) submit(
    PurchaseRequest p,
  ) {
    if (p.status != PurchaseRequestStatus.draft) {
      return (
        result: PurchaseRequestApprovalResult.notAllowedFromCurrentStatus,
        pr: p,
      );
    }
    return (
      result: PurchaseRequestApprovalResult.ok,
      pr: p.copyWith(status: PurchaseRequestStatus.submitted),
    );
  }
}
