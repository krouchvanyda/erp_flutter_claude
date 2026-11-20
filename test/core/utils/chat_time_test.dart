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

  group('day divider', () {
    test('today / yesterday / weekday', () {
      expect(ChatTime.day(DateTime(2026, 11, 20, 7), now: now), 'Today');
      expect(ChatTime.day(DateTime(2026, 11, 19, 23), now: now), 'Yesterday');
      expect(ChatTime.day(DateTime(2026, 11, 16), now: now), 'Monday');
    });

    test('same year → "Fri, 6 Nov"; older year → "12 Nov 2025"', () {
      expect(ChatTime.day(DateTime(2026, 11, 6), now: now), 'Fri, 6 Nov');
      expect(ChatTime.day(DateTime(2025, 11, 12), now: now), '12 Nov 2025');
    });
  });

  test('bubble → HH:mm', () {
    expect(ChatTime.bubble(DateTime(2026, 11, 20, 8, 5)), '08:05');
  });

  test('sameDay', () {
    expect(
      ChatTime.sameDay(DateTime(2026, 1, 1, 0), DateTime(2026, 1, 1, 23)),
      isTrue,
    );
    expect(
      ChatTime.sameDay(DateTime(2026, 1, 1, 23), DateTime(2026, 1, 2, 0)),
      isFalse,
    );
  });
}
