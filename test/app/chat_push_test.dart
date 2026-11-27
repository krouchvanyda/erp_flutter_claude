import 'dart:async';

import 'package:dartz/dartz.dart' show Left, Right;
import 'package:erp_mobile/app/chat_push.dart';
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/push/push_messaging.dart';
import 'package:erp_mobile/core/router/auth_session.dart';
import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/conversation_model.dart';
import 'package:erp_mobile/features/chat/repository/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChat extends Mock implements ChatRepository {}

class _MockPush extends Mock implements PushMessaging {}

const _chat14 = ConversationModel(id: '14', type: ConversationType.direct);

/// Step 5.7: a tapped chat banner → that conversation is asked to open.
void main() {
  late _MockChat chat;
  late _MockPush push;
  late StreamController<Map<String, dynamic>> taps;
  late AuthSession session;
  late ChatPushOpener opener;

  setUp(() {
    chat = _MockChat();
    push = _MockPush();
    taps = StreamController<Map<String, dynamic>>.broadcast();
    session = AuthSession()..markAuthenticated();
    when(() => push.onOpened).thenAnswer((_) => taps.stream);
    when(() => push.launchedBy()).thenAnswer((_) async => null);
    when(
      () => chat.loadConversation('14'),
    ).thenAnswer((_) async => const Right(_chat14));
    opener = ChatPushOpener(session: session, chat: chat);
  });

  tearDown(() async {
    opener.detach();
    await taps.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'tap a chat banner (app in background) → the chat is asked to open',
    () async {
      await opener.attach(push);
      taps.add({'type': 'chat', 'conversationId': '14', 'title': 'Mr Bin'});
      await settle();

      expect(opener.toOpen.value, _chat14);
    },
  );

  test('the tap STARTED the app (killed) → opens too', () async {
    when(
      () => push.launchedBy(),
    ).thenAnswer((_) async => {'type': 'chat', 'conversationId': '14'});
    await opener.attach(push);
    await settle();

    expect(opener.toOpen.value, _chat14);
  });

  test('not a chat push (a call) → ignored', () async {
    await opener.attach(push);
    taps.add({'type': 'call.invite', 'callId': '9'});
    await settle();

    expect(opener.toOpen.value, isNull);
    verifyNever(() => chat.loadConversation(any()));
  });

  test('logged out at the tap → waits, opens right after login', () async {
    session.markLoggedOut();
    await opener.attach(push);
    taps.add({'type': 'chat', 'conversationId': '14'});
    await settle();
    expect(opener.toOpen.value, isNull);
    verifyNever(() => chat.loadConversation(any()));

    session.markAuthenticated();
    await settle();
    expect(opener.toOpen.value, _chat14);
  });

  test(
    'the chat can\'t be loaded (gone / not a member) → stay on the inbox',
    () async {
      when(
        () => chat.loadConversation('14'),
      ).thenAnswer((_) async => const Left(NoInternetError()));
      await opener.attach(push);
      taps.add({'type': 'chat', 'conversationId': '14'});
      await settle();

      expect(opener.toOpen.value, isNull);
    },
  );
}
