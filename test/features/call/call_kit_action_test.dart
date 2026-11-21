import 'package:erp_mobile/features/call/model/call_kit_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CallKitAction.callIdOf (Stream call id → ours)', () {
    test('our calls', () {
      expect(CallKitAction.callIdOf('default:erp-call-12'), '12');
      expect(CallKitAction.callIdOf('erp-call-5'), '5');
    });

    test('not ours / empty → null', () {
      expect(CallKitAction.callIdOf(null), isNull);
      expect(CallKitAction.callIdOf('default:other-12'), isNull);
      expect(CallKitAction.callIdOf('default:erp-call-'), isNull);
    });

    test('cidOf is the way back', () {
      expect(CallKitAction.cidOf('12'), 'default:erp-call-12');
      expect(CallKitAction.callIdOf(CallKitAction.cidOf('12')), '12');
    });
  });

  test('== by value', () {
    expect(
      const CallKitAction(CallKitButton.accept, '1'),
      const CallKitAction(CallKitButton.accept, '1'),
    );
    expect(
      const CallKitAction(CallKitButton.accept, '1'),
      isNot(const CallKitAction(CallKitButton.decline, '1')),
    );
  });
}
