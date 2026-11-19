import 'package:erp_mobile/core/router/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts logged out', () {
    expect(AuthSession().isAuthenticated, isFalse);
  });

  test('notifies only when the value really changes', () {
    final session = AuthSession();
    var calls = 0;
    session.addListener(() => calls++);

    session.markAuthenticated(); // false → true
    session.markAuthenticated(); // true → true (no change)
    session.markLoggedOut(); //     true → false

    expect(calls, 2);
    expect(session.isAuthenticated, isFalse);
  });
}
