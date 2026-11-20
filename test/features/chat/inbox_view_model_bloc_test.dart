import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart' show Left, Right;
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/network/page_model.dart';
import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/conversation_model.dart';
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

  setUp(() {
    repo = _MockChatRepository();
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
}
