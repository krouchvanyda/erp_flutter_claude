import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart' show Left, Right;
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/chat_update.dart';
import 'package:erp_mobile/features/chat/model/conversation_model.dart';
import 'package:erp_mobile/features/chat/model/member_model.dart';
import 'package:erp_mobile/features/chat/repository/chat_repository.dart';
import 'package:erp_mobile/features/chat/viewmodel/conversation_info/conversation_info_view_model_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

ConversationModel group({
  String name = 'Team',
  List<String> members = const ['1', '2'],
}) => ConversationModel(
  id: '7',
  type: ConversationType.group,
  name: name,
  members: [
    for (final id in members)
      MemberModel(
        userId: id,
        role: id == '1' ? MemberRole.admin : MemberRole.member,
      ),
  ],
);

void main() {
  late _MockChatRepository repo;
  late StreamController<ChatUpdate> topic;
  late StreamController<ChatUpdate> inbox;

  setUp(() {
    repo = _MockChatRepository();
    topic = StreamController<ChatUpdate>.broadcast();
    inbox = StreamController<ChatUpdate>.broadcast();
    when(() => repo.conversationUpdates('7')).thenAnswer((_) => topic.stream);
    when(repo.inboxUpdates).thenAnswer((_) => inbox.stream);
  });

  ConversationInfoViewModelBloc build({String myId = '1'}) =>
      ConversationInfoViewModelBloc(repo, conversation: group(), myId: myId);

  test('isAdmin comes from MY member role', () {
    expect(build().isAdmin, isTrue);
    expect(build(myId: '2').isAdmin, isFalse);
  });

  blocTest<ConversationInfoViewModelBloc, ConversationInfoViewModelState>(
    'rename → busy → Ready(new name)',
    setUp: () => when(
      () => repo.rename('7', 'New'),
    ).thenAnswer((_) async => Right(group(name: 'New'))),
    build: build,
    act: (bloc) => bloc.add(OnInfoRenameEvent('  New ')),
    expect: () => [
      isA<ConversationInfoReadyState>().having((s) => s.isBusy, 'busy', true),
      isA<ConversationInfoReadyState>()
          .having((s) => s.conversation.name, 'name', 'New')
          .having((s) => s.isBusy, 'busy', false),
    ],
  );

  blocTest<ConversationInfoViewModelBloc, ConversationInfoViewModelState>(
    'not admin → server 403 → Failed (the old name stays)',
    setUp: () => when(() => repo.rename('7', 'New')).thenAnswer(
      (_) async => const Left(
        ServerError(description: 'Admin role required', statusCode: 403),
      ),
    ),
    build: () => build(myId: '2'),
    act: (bloc) => bloc.add(OnInfoRenameEvent('New')),
    expect: () => [
      isA<ConversationInfoReadyState>(),
      isA<ConversationInfoFailedState>()
          .having((s) => s.conversation.name, 'name', 'Team')
          .having((s) => s.error.statusCode, 'status', 403),
    ],
  );

  blocTest<ConversationInfoViewModelBloc, ConversationInfoViewModelState>(
    'leave OK → Gone(left)',
    setUp: () =>
        when(() => repo.leave('7')).thenAnswer((_) async => const Right(null)),
    build: build,
    act: (bloc) => bloc.add(OnInfoLeaveEvent()),
    expect: () => [
      isA<ConversationInfoReadyState>(),
      isA<ConversationInfoGoneState>().having(
        (s) => s.reason,
        'reason',
        ConversationGoneReason.left,
      ),
    ],
  );

  blocTest<ConversationInfoViewModelBloc, ConversationInfoViewModelState>(
    'live: someone renames / adds → Ready(updated)',
    build: build,
    act: (_) => topic.add(
      ConversationChanged(group(name: 'Renamed', members: ['1', '2', '3'])),
    ),
    expect: () => [
      isA<ConversationInfoReadyState>()
          .having((s) => s.conversation.name, 'name', 'Renamed')
          .having((s) => s.conversation.members.length, 'members', 3),
    ],
  );

  blocTest<ConversationInfoViewModelBloc, ConversationInfoViewModelState>(
    'live: an admin removed ME (I am not in the members) → Gone(removed)',
    build: () => build(myId: '2'),
    act: (_) => topic.add(ConversationChanged(group(members: ['1']))),
    expect: () => [
      isA<ConversationInfoGoneState>().having(
        (s) => s.reason,
        'reason',
        ConversationGoneReason.removed,
      ),
    ],
  );

  blocTest<ConversationInfoViewModelBloc, ConversationInfoViewModelState>(
    'live: deleted (my inbox queue) → Gone; other chats are ignored',
    build: build,
    act: (_) async {
      inbox.add(const ConversationRemoved('99')); // another chat
      await Future<void>.delayed(Duration.zero);
      inbox.add(const ConversationRemoved('7'));
    },
    expect: () => [isA<ConversationInfoGoneState>()],
  );
}
