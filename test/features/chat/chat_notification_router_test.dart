import 'package:erp_mobile/features/chat/repositories/active_conversation_tracker.dart';
import 'package:erp_mobile/features/chat/widgets/chat_notification_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(ChatNotificationRouter.reset);
  tearDown(() => ActiveConversationTracker.instance.leave('42'));

  group('conversationIdOf', () {
    test('reads conversationId from a chat push', () {
      expect(
        ChatNotificationRouter.conversationIdOf(
            {'type': 'chat', 'conversationId': '42'}),
        '42',
      );
    });

    test('accepts snake_case conversation_id', () {
      expect(
          ChatNotificationRouter.conversationIdOf({'conversation_id': '7'}),
          '7');
    });

    test('ignores call pushes even when they carry a conversationId', () {
      expect(
        ChatNotificationRouter.conversationIdOf(
            {'type': 'call.invite', 'conversationId': '42'}),
        isNull,
      );
      expect(
        ChatNotificationRouter.conversationIdOf(
            {'sender': 'stream.video', 'type': 'call.missed'}),
        isNull,
      );
    });

    test('null when there is no conversation id', () {
      expect(ChatNotificationRouter.conversationIdOf({'type': 'chat'}), isNull);
      expect(
          ChatNotificationRouter.conversationIdOf({'conversationId': ''}),
          isNull);
    });
  });

  group('isViewing (foreground banner suppression)', () {
    test('true only for the conversation that is open', () {
      ActiveConversationTracker.instance.enter('42');
      expect(ChatNotificationRouter.isViewing({'conversationId': '42'}),
          isTrue);
      expect(ChatNotificationRouter.isViewing({'conversationId': '43'}),
          isFalse);
    });

    test('false when no conversation is open', () {
      expect(ChatNotificationRouter.isViewing({'conversationId': '42'}),
          isFalse);
    });

    test('never suppresses call pushes', () {
      ActiveConversationTracker.instance.enter('42');
      expect(
        ChatNotificationRouter.isViewing(
            {'type': 'call.invite', 'conversationId': '42'}),
        isFalse,
      );
    });
  });

  group('open (tap)', () {
    test('parks the tap until the inbox is ready (cold start)', () {
      expect(ChatNotificationRouter.open({'conversationId': '42'}), isTrue);
      expect(ChatNotificationRouter.pendingConversationId, '42');
    });

    test('stays parked while there is no navigator yet', () {
      ChatNotificationRouter.open({'conversationId': '42'});
      ChatNotificationRouter.inboxReady(); // no MaterialApp in this test
      expect(ChatNotificationRouter.pendingConversationId, '42');
    });

    test('does nothing for non-chat payloads', () {
      expect(ChatNotificationRouter.open({'type': 'call.invite'}), isFalse);
      expect(ChatNotificationRouter.pendingConversationId, isNull);
    });

    test('does nothing when that conversation is already open', () {
      ActiveConversationTracker.instance.enter('42');
      expect(ChatNotificationRouter.open({'conversationId': '42'}), isTrue);
      expect(ChatNotificationRouter.pendingConversationId, isNull);
    });
  });
}
