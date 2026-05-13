import 'package:erp_mobile/features/procurement/domain/entities/purchase_request.dart';
import 'package:erp_mobile/features/procurement/domain/usecases/pr_approval.dart';
import 'package:test/test.dart';

PurchaseRequest _pr(PurchaseRequestStatus s) => PurchaseRequest(
      id: '1',
      number: 'PR-2026-001',
      requesterName: 'X',
      costCenter: 'CC-1',
      approverName: 'Y',
      createdAt: DateTime.utc(2026, 5, 1),
      status: s,
      totalAmount: r'$100.00',
      lineItems: const [],
    );

void main() {
  const uc = PurchaseRequestApprovalUseCase();

  group('approve', () {
    test('submitted → approved', () {
      final out = uc.approve(_pr(PurchaseRequestStatus.submitted));
      expect(out.result, PurchaseRequestApprovalResult.ok);
      expect(out.pr.status, PurchaseRequestStatus.approved);
    });

    test('any other status → notAllowed (returns input unchanged)', () {
      for (final s in [
        PurchaseRequestStatus.draft,
        PurchaseRequestStatus.approved,
        PurchaseRequestStatus.rejected,
        PurchaseRequestStatus.converted,
      ]) {
        final input = _pr(s);
        final out = uc.approve(input);
        expect(out.result,
            PurchaseRequestApprovalResult.notAllowedFromCurrentStatus);
        expect(out.pr.status, s);
      }
    });
  });

  group('reject', () {
    test('blank reason → reasonRequired (status unchanged)', () {
      final out = uc.reject(_pr(PurchaseRequestStatus.submitted), reason: '   ');
      expect(out.result, PurchaseRequestApprovalResult.reasonRequired);
      expect(out.pr.status, PurchaseRequestStatus.submitted);
    });

    test('submitted + reason → rejected', () {
      final out = uc.reject(_pr(PurchaseRequestStatus.submitted),
          reason: 'over budget');
      expect(out.result, PurchaseRequestApprovalResult.ok);
      expect(out.pr.status, PurchaseRequestStatus.rejected);
    });

    test('cannot reject draft / approved / rejected / converted', () {
      for (final s in [
        PurchaseRequestStatus.draft,
        PurchaseRequestStatus.approved,
        PurchaseRequestStatus.rejected,
        PurchaseRequestStatus.converted,
      ]) {
        final out = uc.reject(_pr(s), reason: 'no');
        expect(out.result,
            PurchaseRequestApprovalResult.notAllowedFromCurrentStatus);
      }
    });
  });

  group('submit (draft → submitted)', () {
    test('draft → submitted', () {
      final out = uc.submit(_pr(PurchaseRequestStatus.draft));
      expect(out.result, PurchaseRequestApprovalResult.ok);
      expect(out.pr.status, PurchaseRequestStatus.submitted);
    });
    test('non-draft → notAllowed', () {
      final out = uc.submit(_pr(PurchaseRequestStatus.submitted));
      expect(out.result,
          PurchaseRequestApprovalResult.notAllowedFromCurrentStatus);
    });
  });
}
