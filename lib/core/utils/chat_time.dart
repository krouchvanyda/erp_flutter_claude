import 'package:intl/intl.dart';

/// Short time labels for chat screens (like most chat apps).
///
/// ```
/// inbox(t)   today → "10:42" · yesterday → "Yesterday" · this week → "Mon"
///            older → "12/11/26"
/// bubble(t)  always "10:42"
/// day(t)     "Today" · "Yesterday" · "Monday" · "Fri, 12 Nov" · "12 Nov 2025"
/// ```
abstract final class ChatTime {
  /// [now] is a parameter so tests can fix "today".
  static String inbox(DateTime time, {DateTime? now}) {
    final daysAgo = _daysAgo(time, now);
    if (daysAgo <= 0) {
      return DateFormat('HH:mm').format(time); // today (or clock skew)
    }
    if (daysAgo == 1) return 'Yesterday';
    if (daysAgo < 7) return DateFormat('EEE').format(time); // Mon
    return DateFormat('dd/MM/yy').format(time);
  }

  /// The small time inside a message bubble.
  static String bubble(DateTime time) => DateFormat('HH:mm').format(time);

  /// The divider between days in a conversation.
  static String day(DateTime time, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final daysAgo = _daysAgo(time, today);
    if (daysAgo <= 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    if (daysAgo < 7) return DateFormat('EEEE').format(time); // Monday
    if (time.year == today.year) {
      return DateFormat('EEE, d MMM').format(time); // Fri, 12 Nov
    }
    return DateFormat('d MMM y').format(time); // 12 Nov 2025
  }

  /// Under a direct chat's title when the person is offline.
  ///
  /// ```
  /// < 1 min ago → "last seen just now"
  /// today       → "last seen 10:42"
  /// yesterday   → "last seen yesterday 22:10"
  /// this year   → "last seen 12 Nov"     · older → "last seen 12 Nov 2025"
  /// ```
  static String lastSeen(DateTime time, {DateTime? now}) {
    final today = now ?? DateTime.now();
    if (today.difference(time).inSeconds < 60) return 'last seen just now';
    final daysAgo = _daysAgo(time, today);
    final hm = DateFormat('HH:mm').format(time);
    if (daysAgo <= 0) return 'last seen $hm';
    if (daysAgo == 1) return 'last seen yesterday $hm';
    if (time.year == today.year) {
      return 'last seen ${DateFormat('d MMM').format(time)}';
    }
    return 'last seen ${DateFormat('d MMM y').format(time)}';
  }

  /// Same calendar day? (for "start a new day divider here")
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _daysAgo(DateTime time, DateTime? now) =>
      _day(now ?? DateTime.now()).difference(_day(time)).inDays;

  /// That calendar day, as a UTC date — so 23:59 yesterday and 00:01 today
  /// are exactly 1 day apart (UTC has no daylight-saving 23-hour days).
  static DateTime _day(DateTime t) => DateTime.utc(t.year, t.month, t.day);
}
