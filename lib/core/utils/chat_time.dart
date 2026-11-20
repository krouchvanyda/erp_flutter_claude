import 'package:intl/intl.dart';

/// Short time labels for chat lists (like most chat apps):
///
/// ```
/// today          → "10:42"
/// yesterday      → "Yesterday"
/// last 6 days    → "Mon"
/// older          → "12/11/26"
/// ```
abstract final class ChatTime {
  /// [now] is a parameter so tests can fix "today".
  static String inbox(DateTime time, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final day = _day(time);
    final daysAgo = today.difference(day).inDays;

    if (daysAgo <= 0) {
      return DateFormat('HH:mm').format(time); // today (or clock skew)
    }
    if (daysAgo == 1) return 'Yesterday';
    if (daysAgo < 7) return DateFormat('EEE').format(time); // Mon
    return DateFormat('dd/MM/yy').format(time);
  }

  /// That calendar day, as a UTC date — so 23:59 yesterday and 00:01 today
  /// are exactly 1 day apart (UTC has no daylight-saving 23-hour days).
  static DateTime _day(DateTime t) => DateTime.utc(t.year, t.month, t.day);
}
