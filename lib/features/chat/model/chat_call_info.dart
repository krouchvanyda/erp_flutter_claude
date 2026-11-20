import 'dart:convert';

import 'chat_enums.dart';
import 'message_model.dart';

/// How a call ended, from the CALLER's side (6.3d).
enum ChatCallOutcome {
  /// Somebody answered → there is a talk time.
  talked,

  /// The caller hung up while it rang.
  cancelled,

  /// Nobody answered (timeout, callee offline / dropped).
  noAnswer,

  /// The callee tapped Decline.
  declined,

  /// The callee was in another call.
  busy,
}

/// A CALL message, read for the screen. The server writes it when a call
/// ends: sender = the caller, `durationSeconds` = talk time, `body` = JSON
/// `{callId, callType, status, endReason, answered}`.
///
/// The words depend on WHO looks ([mine] = I was the caller):
///
/// | outcome   | caller sees                | the others see         |
/// |-----------|----------------------------|------------------------|
/// | talked    | Outgoing voice call · 2:31 | Incoming voice call · 2:31 |
/// | cancelled | Cancelled call             | Missed voice call 🔴   |
/// | noAnswer  | Voice call · No answer     | Missed voice call 🔴   |
/// | declined  | Voice call · Declined      | Declined call          |
/// | busy      | Voice call · Busy          | Missed voice call 🔴   |
///
/// The chat feature's own small model: chat never imports the call feature.
class ChatCallInfo {
  const ChatCallInfo({
    required this.video,
    required this.outcome,
    this.seconds = 0,
  });

  final bool video;
  final ChatCallOutcome outcome;

  /// Talk time (0 when nobody answered).
  final int seconds;

  /// null when [m] isn't a CALL message.
  static ChatCallInfo? of(MessageModel m) {
    if (m.type != MessageType.call || m.deleted) return null;
    Map<String, dynamic> j = const {};
    try {
      final decoded = jsonDecode(m.body ?? '');
      if (decoded is Map<String, dynamic>) j = decoded;
    } catch (_) {
      // unreadable body → a plain "call" line, never a crash
    }
    final status = j['status'];
    final reason = j['endReason'];
    final ChatCallOutcome outcome;
    if (j['answered'] == true) {
      outcome = ChatCallOutcome.talked;
    } else if (status == 'REJECTED') {
      outcome = reason == 'busy'
          ? ChatCallOutcome.busy
          : ChatCallOutcome.declined;
    } else if (status == 'ENDED' && reason == 'caller_left') {
      outcome = ChatCallOutcome.cancelled;
    } else {
      outcome = ChatCallOutcome.noAnswer;
    }
    return ChatCallInfo(
      video: j['callType'] == 'VIDEO',
      outcome: outcome,
      seconds: m.durationSeconds ?? 0,
    );
  }

  String get _kind => video ? 'video call' : 'voice call';

  /// Red for the people who missed it.
  bool missedFor({required bool mine}) =>
      !mine &&
      outcome != ChatCallOutcome.talked &&
      outcome != ChatCallOutcome.declined;

  /// "Outgoing voice call", "Missed video call", …
  String title({required bool mine}) {
    if (missedFor(mine: mine)) return 'Missed $_kind';
    return switch (outcome) {
      ChatCallOutcome.talked => '${mine ? 'Outgoing' : 'Incoming'} $_kind',
      ChatCallOutcome.cancelled => 'Cancelled call',
      ChatCallOutcome.declined when !mine => 'Declined call',
      _ => video ? 'Video call' : 'Voice call',
    };
  }

  /// The second line: "2:31", "No answer", "Declined", "Busy", or null.
  String? detail({required bool mine}) => switch (outcome) {
    ChatCallOutcome.talked => duration(seconds),
    ChatCallOutcome.noAnswer when mine => 'No answer',
    ChatCallOutcome.declined when mine => 'Declined',
    ChatCallOutcome.busy when mine => 'Busy',
    _ => null,
  };

  /// For the inbox: "📞 Missed voice call", "📞 Outgoing voice call · 2:31".
  String preview({required bool mine}) {
    final d = detail(mine: mine);
    return '📞 ${title(mine: mine)}${d == null ? '' : ' · $d'}';
  }

  /// 151 → "2:31", 3725 → "1:02:05".
  static String duration(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
  }

  @override
  bool operator ==(Object other) =>
      other is ChatCallInfo &&
      other.video == video &&
      other.outcome == outcome &&
      other.seconds == seconds;

  @override
  int get hashCode => Object.hash(video, outcome, seconds);

  @override
  String toString() => 'ChatCallInfo(${outcome.name}, video: $video)';
}
