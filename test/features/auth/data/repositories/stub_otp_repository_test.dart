import 'package:erp_mobile/features/auth/data/repositories/stub_otp_repository.dart';
import 'package:erp_mobile/features/auth/domain/entities/otp_verification_result.dart';
import 'package:test/test.dart';

void main() {
  group('StubOtpRepository', () {
    const repo = StubOtpRepository();

    test('accepts the canonical dev code', () async {
      final result = await repo.verify(StubOtpRepository.devCode);
      expect(result, isA<OtpAccepted>());
    });

    test('rejects any other code as incorrect', () async {
      final result = await repo.verify('000000');
      expect(result, isA<OtpRejected>());
      expect((result as OtpRejected).reason, OtpRejectionReason.incorrect);
    });

    test('rejects partial input as incorrect (length check is caller-side)',
        () async {
      final result = await repo.verify('12345');
      expect((result as OtpRejected).reason, OtpRejectionReason.incorrect);
    });

    test('rejects empty input', () async {
      final result = await repo.verify('');
      expect(result, isA<OtpRejected>());
    });
  });
}
