import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/finance/domain/entities/invoice.dart';
import 'package:erp_mobile/features/finance/domain/repositories/invoices_repository.dart';
import 'package:erp_mobile/features/finance/domain/usecases/reopen_invoice.dart';
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
  late ReopenInvoiceUseCase usecase;
  final clock = DateTime.utc(2026, 5, 13);

  setUp(() {
    repo = _MockRepo();
    usecase = ReopenInvoiceUseCase(repository: repo, clock: () => clock);
  });

  test('rejected → draft', () async {
    when(() => repo.findById('inv-1'))
        .thenAnswer((_) async => _inv(InvoiceStatus.rejected));
    when(() => repo.reopen(invoiceId: 'inv-1', actionedAt: clock))
        .thenAnswer((_) async => _inv(InvoiceStatus.draft));

    final out = await usecase(invoiceId: 'inv-1');
    expect(out.status, InvoiceStatus.draft);
  });

  test('non-rejected → ConflictFailure', () async {
    for (final s in [
      InvoiceStatus.draft,
      InvoiceStatus.pendingApproval,
      InvoiceStatus.approved,
    ]) {
      when(() => repo.findById('inv-1')).thenAnswer((_) async => _inv(s));
      await expectLater(
        usecase(invoiceId: 'inv-1'),
        throwsA(isA<ConflictFailure>()),
      );
    }
  });
}
