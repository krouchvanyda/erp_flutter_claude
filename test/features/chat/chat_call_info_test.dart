import 'dart:convert';

import 'package:erp_mobile/features/chat/model/chat_call_info.dart';
import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/message_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A CALL message as the server writes it (6.3d): sender = the caller.
MessageModel _line({
  String status = 'ENDED',
  String? reason,
  bool answered = false,
  int seconds = 0,
  String type = 'VOICE',
}) => MessageModel.fromJson({
  'id': 9,
  'conversationId': 3,
  'senderId': 4,
  'type': 'CALL',
  'durationSeconds': seconds,
  'body': jsonEncode({
    'callId': 46,
    'callType': type,
    'status': status,
    'endReason': reason,
    'answered': answered,
  }),
});

void main() {
  test('MessageType "CALL" is parsed (not mistaken for TEXT)', () {
    expect(MessageType.fromJson('CALL'), MessageType.call);
    expect(_line().previewText, '📞 Call');
  });

  test('talked → Outgoing / Incoming + duration', () {
    final i = ChatCallInfo.of(_line(answered: true, seconds: 151))!;
    expect(i.outcome, ChatCallOutcome.talked);
    expect(i.preview(mine: true), '📞 Outgoing voice call · 2:31');
    expect(i.preview(mine: false), '📞 Incoming voice call · 2:31');
    expect(i.missedFor(mine: false), isFalse);
  });

  test('caller hung up while ringing → "Cancelled call" / "Missed" (red)', () {
    final i = ChatCallInfo.of(_line(reason: 'caller_left'))!;
    expect(i.outcome, ChatCallOutcome.cancelled);
    expect(i.title(mine: true), 'Cancelled call');
    expect(i.title(mine: false), 'Missed voice call');
    expect(i.missedFor(mine: false), isTrue);
  });

  test('no answer → "Voice call · No answer" / "Missed voice call"', () {
    final i = ChatCallInfo.of(_line(status: 'MISSED', reason: 'no_answer'))!;
    expect(i.preview(mine: true), '📞 Voice call · No answer');
    expect(i.preview(mine: false), '📞 Missed voice call');
  });

  test('declined · busy', () {
    final declined = ChatCallInfo.of(
      _line(status: 'REJECTED', reason: 'rejected'),
    )!;
    expect(declined.preview(mine: true), '📞 Voice call · Declined');
    expect(declined.title(mine: false), 'Declined call'); // not red
    expect(declined.missedFor(mine: false), isFalse);

    final busy = ChatCallInfo.of(_line(status: 'REJECTED', reason: 'busy'))!;
    expect(busy.preview(mine: true), '📞 Voice call · Busy');
    expect(busy.title(mine: false), 'Missed voice call');
  });

  test('video words', () {
    final i = ChatCallInfo.of(
      _line(answered: true, seconds: 3725, type: 'VIDEO'),
    )!;
    expect(i.preview(mine: true), '📞 Outgoing video call · 1:02:05');
  });

  test('not a call / deleted / unreadable body → safe', () {
    final text = MessageModel.fromJson({
      'id': 1,
      'conversationId': 3,
      'senderId': 4,
      'type': 'TEXT',
      'body': 'hi',
    });
    expect(ChatCallInfo.of(text), isNull);
    final broken = MessageModel.fromJson({
      'id': 2,
      'conversationId': 3,
      'senderId': 4,
      'type': 'CALL',
      'body': 'not json',
    });
    expect(ChatCallInfo.of(broken)?.outcome, ChatCallOutcome.noAnswer);
  });
}
