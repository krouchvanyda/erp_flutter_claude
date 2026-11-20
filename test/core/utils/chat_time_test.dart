import 'package:erp_mobile/core/utils/chat_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 20, 9, 30); // a Friday

  test('today → HH:mm', () {
    expect(ChatTime.inbox(DateTime(2026, 11, 20, 8, 5), now: now), '08:05');
  });

  test('yesterday, even 23:59 vs 00:01', () {
    expect(
      ChatTime.inbox(
        DateTime(2026, 11, 19, 23, 59),
        now: DateTime(2026, 11, 20, 0, 1),
      ),
      'Yesterday',
    );
  });

  test('this week → weekday, older → date', () {
    expect(ChatTime.inbox(DateTime(2026, 11, 16), now: now), 'Mon');
    expect(ChatTime.inbox(DateTime(2026, 11, 12), now: now), '12/11/26');
  });
}
