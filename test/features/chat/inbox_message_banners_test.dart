import 'dart:async';

import 'package:erp_mobile/core/router/config_router.dart';
import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/conversation_model.dart';
import 'package:erp_mobile/features/chat/model/member_model.dart';
import 'package:erp_mobile/features/chat/model/message_model.dart';
import 'package:erp_mobile/features/chat/viewmodel/inbox/inbox_view_model_bloc.dart';
import 'package:erp_mobile/features/chat/widgets/inbox_message_banners.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _members = [
  MemberModel(userId: '1', fullName: 'Me'),
  MemberModel(userId: '2', fullName: 'Mr Bin'),
];
const _direct = ConversationModel(
  id: '14',
  type: ConversationType.direct,
  members: _members,
);
const _group = ConversationModel(
  id: '20',
  type: ConversationType.group,
  name: 'Team A',
  members: _members,
);
const _hi = MessageModel(
  id: '7',
  conversationId: '14',
  senderId: '2',
  type: MessageType.text,
  body: 'Hi',
);

/// Step 5.7: the in-app banner — on every screen while the app is open.
void main() {
  test('text: "Hi" in a direct chat, "Mr Bin: Hi" in a group', () {
    expect(
      InboxMessageBanners.messageText((conversation: _direct, message: _hi)),
      'Hi',
    );
    expect(
      InboxMessageBanners.messageText((conversation: _group, message: _hi)),
      'Mr Bin: Hi',
    );
  });

  group('on screen', () {
    late StreamController<InboxIncomingMessage> news;
    late List<String> opened;
    final navigator = GlobalKey<NavigatorState>();

    setUp(() {
      news = StreamController<InboxIncomingMessage>.broadcast();
      opened = [];
    });
    tearDown(() => news.close());

    Future<void> pumpInbox(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: InboxMessageBanners(
            incoming: news.stream,
            myId: () => '1',
            onOpen: (c) => opened.add(c.id),
            child: const Scaffold(body: Text('inbox')),
          ),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pumpAndSettle(); // the slide-in finishes
    }

    testWidgets('on the Chats list too → banner; tap → opens that chat', (
      tester,
    ) async {
      await pumpInbox(tester);
      news.add((conversation: _direct, message: _hi));
      await settle(tester);
      expect(find.text('Mr Bin'), findsOneWidget);

      await tester.tap(find.text('Hi'));
      await tester.pump();
      expect(opened, ['14']);
    });

    testWidgets('another screen on top → banner; tap → opens that chat', (
      tester,
    ) async {
      await pumpInbox(tester);
      // the app's real push (an opaque PageTransition), like opening a chat
      unawaited(
        ConfigRouter.pushPageAnimation<void>(
          navigator.currentContext!,
          const Scaffold(body: Text('another chat')),
        ),
      );
      await tester.pumpAndSettle();

      news.add((conversation: _direct, message: _hi));
      await settle(tester);
      expect(find.text('Mr Bin'), findsOneWidget);
      expect(find.text('Hi'), findsOneWidget);

      await tester.tap(find.text('Hi'));
      await tester.pump();
      expect(opened, ['14']);
      expect(find.text('Mr Bin'), findsNothing); // closed on tap
    });

    testWidgets(
      'the app is in the background → no banner (the OS push does it)',
      (tester) async {
        await pumpInbox(tester);
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('x')),
          ),
        );
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

        news.add((conversation: _direct, message: _hi));
        await settle(tester);
        expect(find.text('Mr Bin'), findsNothing);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      },
    );
  });
}
