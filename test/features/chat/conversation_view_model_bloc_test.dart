import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart' show Left, Right;
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/network/page_model.dart';
import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/message_model.dart';
import 'package:erp_mobile/features/chat/repository/chat_repository.dart';
import 'package:erp_mobile/features/chat/viewmodel/conversation_view_model_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

MessageModel msg(String id, {String sender = '2', String body = 'x'}) =>
    MessageModel(
      id: id,
      conversationId: 'c1',
      senderId: sender,
      type: MessageType.text,
      body: body,
    );

PageModel<MessageModel> pageOf(
  List<String> ids, {
  int page = 1,
  int totalPages = 1,
}) => PageModel(
  items: [for (final id in ids) msg(id)],
  page: page,
  pageSize: 30,
  totalItems: 0,
  totalPages: totalPages,
);

void main() {
  late _MockChatRepository repo;
  late Completer<void> gate;

  setUp(() {
    repo = _MockChatRepository();
    when(
      () => repo.markRead(any(), any()),
    ).thenAnswer((_) async => const Right(null));
  });

  ConversationViewModelBloc build() =>
      ConversationViewModelBloc(repo, conversationId: 'c1');

  ConversationLoadedState loaded(
    List<String> ids, {
    int page = 1,
    bool hasMore = false,
  }) => ConversationLoadedState(
    messages: [for (final id in ids) msg(id)],
    page: page,
    hasMore: hasMore,
  );

  blocTest<ConversationViewModelBloc, ConversationViewModelState>(
    'first load → [Loading, Loaded] and marks the NEWEST message read once',
    setUp: () => when(
      () => repo.loadMessages('c1'),
    ).thenAnswer((_) async => Right(pageOf(['3', '2', '1']))),
    build: build,
    act: (bloc) async {
      bloc.add(OnConversationLoadEvent());
      await Future<void>.delayed(Duration.zero);
      bloc.add(OnConversationLoadEvent()); // same newest → no 2nd /read
    },
    expect: () => [
      isA<ConversationLoadingState>(),
      isA<ConversationLoadedState>().having(
        (s) => s.messages.map((m) => m.id),
        'ids',
        ['3', '2', '1'],
      ),
    ],
    verify: (_) => verify(() => repo.markRead('c1', '3')).called(1),
  );

  blocTest<ConversationViewModelBloc, ConversationViewModelState>(
    'first load fails → Error with NO data (full error view)',
    setUp: () => when(
      () => repo.loadMessages('c1'),
    ).thenAnswer((_) async => const Left(NoInternetError())),
    build: build,
    act: (bloc) => bloc.add(OnConversationLoadEvent()),
    expect: () => [
      isA<ConversationLoadingState>(),
      isA<ConversationErrorState>().having((s) => s.data, 'data', isNull),
    ],
    verify: (_) => verifyNever(() => repo.markRead(any(), any())),
  );

  blocTest<ConversationViewModelBloc, ConversationViewModelState>(
    'load older → page 2 appended at the END (older), duplicates dropped',
    setUp: () {
      gate = Completer<void>();
      when(() => repo.loadMessages('c1', page: 2)).thenAnswer((_) async {
        await gate.future; // keep page 2 "on its way"
        return Right(pageOf(['2', '1', '0'], page: 2, totalPages: 3));
      });
    },
    build: build,
    seed: () => loaded(['3', '2'], hasMore: true),
    act: (bloc) async {
      bloc.add(OnConversationLoadOlderEvent());
      await Future<void>.delayed(Duration.zero);
      bloc.add(OnConversationLoadOlderEvent()); // ignored: still loading
      await Future<void>.delayed(Duration.zero);
      gate.complete();
    },
    expect: () => [
      isA<ConversationLoadedState>().having(
        (s) => s.isLoadingOlder,
        'busy',
        true,
      ),
      isA<ConversationLoadedState>()
          .having((s) => s.messages.map((m) => m.id), 'ids', [
            '3',
            '2',
            '1',
            '0',
          ])
          .having((s) => s.page, 'page', 2)
          .having((s) => s.hasMore, 'hasMore', true),
    ],
    verify: (_) => verify(() => repo.loadMessages('c1', page: 2)).called(1),
  );

  blocTest<ConversationViewModelBloc, ConversationViewModelState>(
    'send OK → 🕓 outgoing at once → replaced by the server message',
    setUp: () => when(
      () => repo.sendText('c1', 'Hello'),
    ).thenAnswer((_) async => Right(msg('4', sender: '1', body: 'Hello'))),
    build: build,
    seed: () => loaded(['3']),
    act: (bloc) => bloc.add(OnMessageSendEvent('  Hello  ')), // trimmed
    expect: () => [
      isA<ConversationLoadedState>()
          .having((s) => s.outgoing.single.text, 'outgoing', 'Hello')
          .having((s) => s.outgoing.single.failed, 'failed', false),
      isA<ConversationLoadedState>()
          .having((s) => s.outgoing, 'outgoing', isEmpty)
          .having((s) => s.messages.map((m) => m.id), 'ids', ['4', '3']),
    ],
  );

  blocTest<ConversationViewModelBloc, ConversationViewModelState>(
    'send fails → bubble marked failed (text kept) → retry OK',
    setUp: () {
      var calls = 0;
      when(() => repo.sendText('c1', 'Hi')).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? const Left(NoInternetError())
            : Right(msg('4', sender: '1', body: 'Hi'));
      });
    },
    build: build,
    seed: () => loaded(['3']),
    act: (bloc) async {
      bloc.add(OnMessageSendEvent('Hi'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(OnMessageRetryEvent('local-1'));
    },
    expect: () => [
      isA<ConversationLoadedState>().having(
        (s) => s.outgoing.single.failed,
        'sending',
        false,
      ),
      isA<ConversationLoadedState>().having(
        (s) => s.outgoing.single.failed,
        'failed',
        true,
      ),
      isA<ConversationLoadedState>().having(
        (s) => s.outgoing.single.failed,
        'retrying',
        false,
      ),
      isA<ConversationLoadedState>()
          .having((s) => s.outgoing, 'outgoing', isEmpty)
          .having((s) => s.messages.first.id, 'newest', '4'),
    ],
  );

  blocTest<ConversationViewModelBloc, ConversationViewModelState>(
    'blank text and "no data yet" are ignored',
    build: build,
    act: (bloc) => bloc.add(OnMessageSendEvent('hi')), // still Initial
    expect: () => <ConversationViewModelState>[],
    verify: (_) => verifyNever(() => repo.sendText(any(), any())),
  );

  blocTest<ConversationViewModelBloc, ConversationViewModelState>(
    'sending while the error banner shows keeps the Error state (banner stays)',
    setUp: () => when(
      () => repo.sendText('c1', 'Hi'),
    ).thenAnswer((_) async => Right(msg('4', sender: '1', body: 'Hi'))),
    build: build,
    seed: () => ConversationErrorState(
      error: const NoInternetError(),
      lastData: loaded(['3']),
    ),
    act: (bloc) => bloc.add(OnMessageSendEvent('Hi')),
    expect: () => [
      isA<ConversationErrorState>().having(
        (s) => s.data!.outgoing.length,
        'outgoing',
        1,
      ),
      isA<ConversationErrorState>().having(
        (s) => s.data!.messages.map((m) => m.id),
        'ids',
        ['4', '3'],
      ),
    ],
  );

  test('reload with an unchanged list still completes done', () async {
    when(
      () => repo.loadMessages('c1'),
    ).thenAnswer((_) async => Right(pageOf(['1'])));
    final bloc = build()..add(OnConversationLoadEvent());
    await bloc.stream.firstWhere((s) => s is ConversationLoadedState);

    final done = Completer<void>();
    bloc.add(OnConversationLoadEvent(done: done));
    await done.future.timeout(const Duration(seconds: 1));
    await bloc.close();
  });

  blocTest<ConversationViewModelBloc, ConversationViewModelState>(
    'a message sent DURING a reload is not lost',
    setUp: () {
      final gate = Completer<void>();
      when(() => repo.loadMessages('c1')).thenAnswer((_) async {
        await gate.future;
        return Right(pageOf(['3']));
      });
      when(() => repo.sendText('c1', 'Hi')).thenAnswer((_) async {
        gate.complete(); // the reload finishes AFTER the bubble was added
        return const Left(NoInternetError());
      });
    },
    build: build,
    seed: () => loaded(['3']),
    act: (bloc) async {
      bloc.add(OnConversationLoadEvent());
      await Future<void>.delayed(Duration.zero);
      bloc.add(OnMessageSendEvent('Hi'));
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.data!.outgoing.single.text, 'Hi');
    },
  );
}
