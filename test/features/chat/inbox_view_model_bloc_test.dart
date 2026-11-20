import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart' show Left, Right;
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/network/page_model.dart';
import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/chat_update.dart';
import 'package:erp_mobile/features/chat/model/conversation_model.dart';
import 'package:erp_mobile/features/chat/model/message_model.dart';
import 'package:erp_mobile/features/chat/repository/chat_repository.dart';
import 'package:erp_mobile/features/chat/viewmodel/inbox_view_model_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

ConversationModel chat(String id) =>
    ConversationModel(id: id, type: ConversationType.direct);

PageModel<ConversationModel> pageOf(
  List<String> ids, {
  int page = 1,
  int totalPages = 1,
}) => PageModel(
  items: [for (final id in ids) chat(id)],
  page: page,
  pageSize: 20,
  totalItems: 0,
  totalPages: totalPages,
);

void main() {
  late _MockChatRepository repo;
  late StreamController<ChatUpdate> updates;
  late StreamController<void> reconnected;

  setUp(() {
    repo = _MockChatRepository();
    updates = StreamController<ChatUpdate>.broadcast();
    reconnected = StreamController<void>.broadcast();
    when(repo.inboxUpdates).thenAnswer((_) => updates.stream);
    when(() => repo.reconnected).thenAnswer((_) => reconnected.stream);
    when(repo.myUserId).thenAnswer((_) async => '1');
  });

  blocTest<InboxViewModelBloc, InboxViewModelState>(
    'first load → [Loading, Loaded(page 1, myId)]',
    setUp: () => when(
      () => repo.loadInbox(),
    ).thenAnswer((_) async => Right(pageOf(['a', 'b'], totalPages: 2))),
    build: () => InboxViewModelBloc(repo),
    act: (bloc) => bloc.add(OnInboxLoadEvent()),
    expect: () => [
      isA<InboxLoadingState>(),
      isA<InboxLoadedState>()
          .having((s) => s.conversations.length, 'count', 2)
          .having((s) => s.myId, 'myId', '1')
          .having((s) => s.hasMore, 'hasMore', true),
    ],
  );

  blocTest<InboxViewModelBloc, InboxViewModelState>(
    'load more → appends page 2, drops a duplicate id',
    setUp: () => when(() => repo.loadInbox(page: 2)).thenAnswer(
      (_) async => Right(pageOf(['b', 'c'], page: 2, totalPages: 2)),
    ),
    build: () => InboxViewModelBloc(repo),
    seed: () => InboxLoadedState(
      conversations: [chat('a'), chat('b')],
      myId: '1',
      page: 1,
      hasMore: true,
    ),
    act: (bloc) => bloc.add(OnInboxLoadMoreEvent()),
    expect: () => [
      isA<InboxLoadedState>().having((s) => s.isLoadingMore, 'more', true),
      isA<InboxLoadedState>()
          .having((s) => s.conversations.map((c) => c.id), 'ids', [
            'a',
            'b',
            'c',
          ])
          .having((s) => s.hasMore, 'hasMore', false)
          .having((s) => s.isLoadingMore, 'more', false),
    ],
  );

  blocTest<InboxViewModelBloc, InboxViewModelState>(
    'no more pages → load more does nothing',
    build: () => InboxViewModelBloc(repo),
    seed: () => InboxLoadedState(
      conversations: [chat('a')],
      myId: '1',
      page: 1,
      hasMore: false,
    ),
    act: (bloc) => bloc.add(OnInboxLoadMoreEvent()),
    expect: () => <InboxViewModelState>[],
  );

  blocTest<InboxViewModelBloc, InboxViewModelState>(
    'refresh fails → NO Loading, Error KEEPS the list',
    setUp: () => when(
      () => repo.loadInbox(),
    ).thenAnswer((_) async => const Left(NoInternetError())),
    build: () => InboxViewModelBloc(repo),
    seed: () => InboxLoadedState(
      conversations: [chat('a')],
      myId: '1',
      page: 1,
      hasMore: false,
    ),
    act: (bloc) => bloc.add(OnInboxLoadEvent()),
    expect: () => [
      isA<InboxErrorState>().having(
        (s) => s.data?.conversations.length,
        'kept',
        1,
      ),
    ],
  );

  // The "refresh spins forever" bug: the same list → the new state is == the
  // old one → Bloc emits NOTHING. The page must still be told "finished".
  test(
    'refresh with an unchanged list emits nothing but completes done',
    () async {
      when(
        () => repo.loadInbox(),
      ).thenAnswer((_) async => Right(pageOf(['a'])));
      final bloc = InboxViewModelBloc(repo)..add(OnInboxLoadEvent());
      await bloc.stream.firstWhere((s) => s is InboxLoadedState);

      final emitted = <InboxViewModelState>[];
      final sub = bloc.stream.listen(emitted.add);
      final done = Completer<void>();
      bloc.add(OnInboxLoadEvent(done: done));

      await done.future.timeout(const Duration(seconds: 1));
      expect(emitted, isEmpty); // proves why waiting for a state would hang
      await sub.cancel();
      await bloc.close();
    },
  );

  test('refresh that fails also completes done', () async {
    when(
      () => repo.loadInbox(),
    ).thenAnswer((_) async => const Left(NoInternetError()));
    final bloc = InboxViewModelBloc(repo);
    final done = Completer<void>();
    bloc.add(OnInboxLoadEvent(done: done));
    await done.future.timeout(const Duration(seconds: 1));
    expect(bloc.state, isA<InboxErrorState>());
    await bloc.close();
  });

  // ─────────────── Step 5.3: live ───────────────

  group('live', () {
    MessageModel incoming(String conv, {String from = '2', String id = '99'}) =>
        MessageModel(
          id: id,
          conversationId: conv,
          senderId: from,
          type: MessageType.text,
          body: 'new',
        );

    InboxLoadedState seeded(List<ConversationModel> list) => InboxLoadedState(
      conversations: list,
      myId: '1',
      page: 1,
      hasMore: false,
    );

    List<String> ids(InboxViewModelState s) => [
      for (final c in s.data!.conversations) c.id,
    ];

    blocTest<InboxViewModelBloc, InboxViewModelState>(
      'a message from someone → preview, unread +1, moved to the TOP',
      build: () => InboxViewModelBloc(repo),
      seed: () => seeded([chat('a'), chat('b')]),
      act: (_) => updates.add(MessageArrived(incoming('b'))),
      expect: () => [
        isA<InboxLoadedState>()
            .having(ids, 'order', ['b', 'a'])
            .having((s) => s.conversations.first.unreadCount, 'unread', 1)
            .having(
              (s) => s.conversations.first.lastMessage?.body,
              'preview',
              'new',
            ),
      ],
    );

    blocTest<InboxViewModelBloc, InboxViewModelState>(
      'my own message, or one in the OPEN chat → no unread',
      build: () => InboxViewModelBloc(repo),
      seed: () => seeded([chat('a'), chat('b')]),
      act: (bloc) async {
        updates.add(MessageArrived(incoming('a', from: '1', id: '1')));
        await Future<void>.delayed(Duration.zero);
        bloc.add(OnInboxConversationOpenedEvent('b'));
        await Future<void>.delayed(Duration.zero);
        updates.add(MessageArrived(incoming('b', id: '2')));
      },
      verify: (bloc) {
        expect(
          bloc.state.data!.conversations.every((c) => c.unreadCount == 0),
          isTrue,
        );
        expect(ids(bloc.state), ['b', 'a']);
      },
    );

    blocTest<InboxViewModelBloc, InboxViewModelState>(
      'a chat we never loaded → GET it, then insert at the top',
      setUp: () => when(
        () => repo.loadConversation('z'),
      ).thenAnswer((_) async => Right(chat('z'))),
      build: () => InboxViewModelBloc(repo),
      seed: () => seeded([chat('a')]),
      act: (_) => updates.add(MessageArrived(incoming('z'))),
      expect: () => [
        isA<InboxLoadedState>().having(ids, 'order', ['z', 'a']),
      ],
    );

    blocTest<InboxViewModelBloc, InboxViewModelState>(
      'conversation.update keeps OUR unread count; remove drops it',
      build: () => InboxViewModelBloc(repo),
      seed: () => seeded([
        const ConversationModel(
          id: 'a',
          type: ConversationType.group,
          unreadCount: 4,
        ),
        chat('b'),
      ]),
      act: (bloc) async {
        updates.add(
          const ConversationChanged(
            ConversationModel(
              id: 'a',
              type: ConversationType.group,
              name: 'New name',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        updates.add(const ConversationRemoved('b'));
      },
      verify: (bloc) {
        final a = bloc.state.data!.conversations.single;
        expect(a.name, 'New name');
        expect(a.unreadCount, 4); // not the sender's count from the server
      },
    );

    blocTest<InboxViewModelBloc, InboxViewModelState>(
      'connection back → reload page 1 (catch-up)',
      setUp: () => when(
        () => repo.loadInbox(),
      ).thenAnswer((_) async => Right(pageOf(['a']))),
      build: () => InboxViewModelBloc(repo),
      seed: () => seeded([chat('a')]),
      act: (_) => reconnected.add(null),
      verify: (_) => verify(() => repo.loadInbox()).called(1),
    );
  });
}
