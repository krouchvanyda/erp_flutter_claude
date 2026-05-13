import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/finance/domain/entities/invoice.dart';
import 'package:erp_mobile/features/finance/domain/repositories/invoices_repository.dart';
import 'package:erp_mobile/features/finance/domain/usecases/submit_invoice_for_approval.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRepo extends Mock implements InvoicesRepository {}

Invoice _inv(InvoiceStatus s) => Invoice(
      id: 'inv-1',
      invoiceNumber: 'INV-001',
      customerName: 'Acme',
      issuedAt: DateTime.utc(2026, 5, 1),
      dueAt: DateTime.utc(2026, 6, 1),
      status: s,
      totalAmount: r'$1.00',
    );

void main() {
  late _MockRepo repo;
  late SubmitInvoiceForApprovalUseCase usecase;
  final clock = DateTime.utc(2026, 5, 13);

  setUp(() {
    repo = _MockRepo();
    usecase = SubmitInvoiceForApprovalUseCase(
      repository: repo,
      clock: () => clock,
    );
  });

  test('draft → pendingApproval', () async {
    when(() => repo.findById('inv-1'))
        .thenAnswer((_) async => _inv(InvoiceStatus.draft));
    when(() => repo.submitForApproval(
          invoiceId: 'inv-1',
          actionedAt: clock,
        )).thenAnswer(
      (_) async => _inv(InvoiceStatus.pendingApproval),
    );

    final out = await usecase(invoiceId: 'inv-1');
    expect(out.status, InvoiceStatus.pendingApproval);
  });

  test('non-draft → ConflictFailure', () async {
    for (final s in [
      InvoiceStatus.pendingApproval,
      InvoiceStatus.approved,
      InvoiceStatus.rejected,
    ]) {
      when(() => repo.findById('inv-1'))
          .thenAnswer((_) async => _inv(s));
      await expectLater(
        usecase(invoiceId: 'inv-1'),
        throwsA(isA<ConflictFailure>()),
      );
    }
  });

  test('unknown id → NotFoundFailure', () async {
    when(() => repo.findById('nope')).thenAnswer((_) async => null);
    await expectLater(
      usecase(invoiceId: 'nope'),
      throwsA(isA<NotFoundFailure>()),
    );
  });
}
