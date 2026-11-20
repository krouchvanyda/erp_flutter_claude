import 'package:erp_mobile/core/realtime/realtime_event.dart';
import 'package:erp_mobile/features/chat/model/chat_update.dart';
import 'package:flutter_test/flutter_test.dart';

ChatUpdate? parse(String event, Object? payload) =>
    ChatUpdate.fromRealtime(RealtimeEvent(event: event, payload: payload));

void main() {
  test('message.send → MessageArrived', () {
    final u = parse('message.send', {
      'id': 9,
      'conversationId': 5,
      'senderId': 2,
      'type': 'TEXT',
      'body': 'hi',
    });
    expect((u! as MessageArrived).message.body, 'hi');
  });

  test('message.edit / message.delete → MessageChanged', () {
    expect(
      parse('message.delete', {'id': 9, 'deleted': true}),
      isA<MessageChanged>(),
    );
  });

  test('message.read → MessagesRead (numbers → strings)', () {
    final u =
        parse('message.read', {
              'conversationId': 5,
              'userId': 2,
              'lastReadMessageId': 42,
            })!
            as MessagesRead;
    expect((u.userId, u.lastReadMessageId), ('2', '42'));
  });

  test('conversation.remove: a DTO or just {conversationId}', () {
    expect(
      (parse('conversation.remove', {'id': 5})! as ConversationRemoved)
          .conversationId,
      '5',
    );
    expect(
      (parse('conversation.remove', {'conversationId': 6})!
              as ConversationRemoved)
          .conversationId,
      '6',
    );
  });

  test('unknown events and bad payloads → null (ignored)', () {
    expect(parse('reaction.toggle', {'x': 1}), isNull);
    expect(parse('message.send', 'not a map'), isNull);
  });
}
