import 'dart:async';

import 'package:dartz/dartz.dart' show Right;
import 'package:erp_mobile/core/network/page_model.dart';
import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/message_model.dart';
import 'package:erp_mobile/features/chat/repository/chat_repository.dart';
import 'package:erp_mobile/features/chat/viewmodel/message_search/message_search_view_model_bloc.dart';
import 'package:erp_mobile/features/chat/widgets/message_search_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

PageModel<MessageModel> pageOf(String q, {int page = 1, int totalPages = 1}) =>
    PageModel(
      items: [
        MessageModel(
          id: '$q-$page',
          conversationId: 'c1',
          senderId: '2',
          type: MessageType.text,
          body: q,
        ),
      ],
      page: page,
      pageSize: 30,
      totalItems: 0,
      totalPages: totalPages,
    );

void main() {
  late _MockChatRepository repo;
  late List<String> asked;

  setUp(() {
    repo = _MockChatRepository();
    asked = [];
    when(
      () => repo.searchMessages('c1', any(), page: any(named: 'page')),
    ).thenAnswer((i) async {
      final q = i.positionalArguments[1] as String;
      final page = i.namedArguments[#page] as int;
      asked.add('$q#$page');
      return Right(pageOf(q, page: page, totalPages: 2));
    });
  });

  MessageSearchViewModelBloc build() => MessageSearchViewModelBloc(
    repo,
    conversationId: 'c1',
    debounce: const Duration(milliseconds: 30),
  );

  Future<void> wait([int ms = 60]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  test('typing fast → ONE request for the last text', () async {
    final bloc = build();
    for (final q in ['m', 'me', 'mee', 'meet']) {
      bloc.add(OnSearchQueryChangedEvent(q));
    }
    await wait();
    expect(asked, ['meet#1']);
    expect(
      (bloc.state as MessageSearchLoadedState).results.single.body,
      'meet',
    );
    await bloc.close();
  });

  test('clearing the box → back to Initial (no request)', () async {
    final bloc = build()..add(OnSearchQueryChangedEvent('x'));
    bloc.add(OnSearchQueryChangedEvent('  '));
    await wait();
    expect(bloc.state, isA<MessageSearchInitial>());
    expect(asked, isEmpty);
    await bloc.close();
  });

  test('an answer for an OLD query is thrown away', () async {
    final slow = Completer<void>();
    when(
      () => repo.searchMessages('c1', 'old', page: any(named: 'page')),
    ).thenAnswer((_) async {
      await slow.future;
      return Right(pageOf('old'));
    });
    final bloc = build()..add(OnSearchQueryChangedEvent('old'));
    await wait(); // "old" is now waiting for the server
    bloc.add(OnSearchQueryChangedEvent('new'));
    await wait();
    slow.complete(); // the old answer arrives late
    await wait(10);
    expect((bloc.state as MessageSearchLoadedState).query, 'new');
    await bloc.close();
  });

  test('load more → page 2 appended', () async {
    final bloc = build()..add(OnSearchQueryChangedEvent('meet'));
    await wait();
    bloc.add(OnSearchLoadMoreEvent());
    await wait(10);
    expect(asked, ['meet#1', 'meet#2']);
    expect((bloc.state as MessageSearchLoadedState).results, hasLength(2));
    await bloc.close();
  });

  test('highlight split: every match, any case', () {
    expect(MessageSearchTile.split('Meet at the meeting', 'meet'), [
      ('Meet', true),
      (' at the ', false),
      ('meet', true),
      ('ing', false),
    ]);
    expect(MessageSearchTile.split('hello', ''), [('hello', false)]);
  });
}
