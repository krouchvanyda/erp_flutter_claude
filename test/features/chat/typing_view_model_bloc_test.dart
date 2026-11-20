import 'dart:async';

import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/chat_update.dart';
import 'package:erp_mobile/features/chat/model/message_model.dart';
import 'package:erp_mobile/features/chat/repository/chat_repository.dart';
import 'package:erp_mobile/features/chat/viewmodel/typing/typing_view_model_bloc.dart';
import 'package:erp_mobile/features/chat/widgets/conversation_app_bar_title.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late _MockChatRepository repo;
  late StreamController<ChatUpdate> topic;
  late List<bool> sent; // what I told the server
  late DateTime now;

  setUp(() {
    repo = _MockChatRepository();
    topic = StreamController<ChatUpdate>.broadcast();
    sent = [];
    now = DateTime(2026, 11, 20, 10);
    when(() => repo.conversationUpdates('c1')).thenAnswer((_) => topic.stream);
    when(() => repo.sendTyping('c1', typing: any(named: 'typing'))).thenAnswer((
      i,
    ) {
      sent.add(i.namedArguments[#typing] as bool);
      return true;
    });
  });

  TypingViewModelBloc build() => TypingViewModelBloc(
    repo,
    conversationId: 'c1',
    myId: '1',
    idleAfter: const Duration(milliseconds: 40),
    expireAfter: const Duration(milliseconds: 40),
    clock: () => now,
  );

  Future<void> tick([int ms = 0]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  group('out (me)', () {
    test('typing fast → ONE "true" per 3 s, not one per key', () async {
      final bloc = build();
      for (final t in ['H', 'He', 'Hel', 'Hell']) {
        bloc.add(OnTypingTextChangedEvent(t));
        await tick();
      }
      expect(sent, [true]);

      now = now.add(const Duration(seconds: 3)); // still typing 3 s later
      bloc.add(OnTypingTextChangedEvent('Hello'));
      await tick();
      expect(sent, [true, true]); // refresh, so their 6 s timer doesn't end
      await bloc.close();
    });

    test('stop typing for a while → "false" once', () async {
      final bloc = build()..add(OnTypingTextChangedEvent('Hi'));
      await tick(80); // > idleAfter
      expect(sent, [true, false]);
      await bloc.close();
      expect(sent, [true, false]); // closing doesn't send a 2nd false
    });

    test('clear the box / send → "false" at once', () async {
      final bloc = build()..add(OnTypingTextChangedEvent('Hi'));
      await tick();
      bloc.add(OnTypingStopEvent());
      await tick();
      expect(sent, [true, false]);
      await bloc.close();
    });

    test('leaving the chat while typing → "false"', () async {
      final bloc = build()..add(OnTypingTextChangedEvent('Hi'));
      await tick();
      await bloc.close();
      expect(sent, [true, false]);
    });
  });

  group('in (them)', () {
    TypingChanged typing(String user, {bool on = true, String conv = 'c1'}) =>
        TypingChanged(conversationId: conv, userId: user, typing: on);

    test('they type → shown; my own echo / other chats ignored', () async {
      final bloc = build();
      topic
        ..add(typing('2'))
        ..add(typing('1')) // me (the server echoes to everyone)
        ..add(typing('3', conv: 'other'));
      await tick();
      expect(bloc.state.userIds, {'2'});
      await bloc.close();
    });

    test(
      'no refresh → expires by itself (a lost "false" can\'t stick)',
      () async {
        final bloc = build();
        topic.add(typing('2'));
        await tick();
        expect(bloc.state.anyone, isTrue);
        await tick(80); // > expireAfter
        expect(bloc.state.anyone, isFalse);
        await bloc.close();
      },
    );

    test('"false" or their message → removed at once', () async {
      final bloc = build();
      topic
        ..add(typing('2'))
        ..add(typing('3'));
      await tick();
      topic.add(typing('2', on: false));
      topic.add(
        const MessageArrived(
          MessageModel(
            id: '9',
            conversationId: 'c1',
            senderId: '3',
            type: MessageType.text,
          ),
        ),
      );
      await tick();
      expect(bloc.state.userIds, isEmpty);
      await bloc.close();
    });
  });

  test('typingLabel: direct / 1 / 2 / 3+ people', () {
    String? label(List<String> n, {bool group = true}) =>
        ConversationAppBarTitle.typingLabel(n, isGroup: group);
    expect(label([]), isNull);
    expect(label(['Jane Doe'], group: false), 'typing…');
    expect(label(['Dara Sok']), 'Dara is typing…');
    expect(label(['Dara Sok', 'Jane Doe']), 'Dara and Jane are typing…');
    expect(label(['A', 'B', 'C']), '3 people are typing…');
  });
}
