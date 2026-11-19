import 'package:erp_mobile/core/utils/validators/form_validators.dart';
import 'package:erp_mobile/core/utils/validators/validation_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loginEmail', () {
    test('empty → required', () {
      expect(FormValidators.loginEmail(''), ValidationMessages.required);
      expect(FormValidators.loginEmail('   '), ValidationMessages.required);
    });
    test('bad → invalid', () {
      expect(
        FormValidators.loginEmail('vanyda'),
        ValidationMessages.emailInvalid,
      );
      expect(FormValidators.loginEmail('a@b'), ValidationMessages.emailInvalid);
    });
    test('good → null', () {
      expect(FormValidators.loginEmail('v@x.com'), isNull);
      expect(FormValidators.loginEmail(' v@x.com '), isNull);
    });
  });

  group('loginPassword (backend: 6–100 chars)', () {
    test('empty → required', () {
      expect(FormValidators.loginPassword(''), ValidationMessages.required);
    });
    test('5 chars → too short', () {
      expect(
        FormValidators.loginPassword('12345'),
        ValidationMessages.passwordShort,
      );
    });
    test('6 chars → ok', () {
      expect(FormValidators.loginPassword('123456'), isNull);
    });
  });
}
