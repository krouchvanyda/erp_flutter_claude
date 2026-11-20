import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart' show Left, Right;
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/network/page_model.dart';
import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/contact_model.dart';
import 'package:erp_mobile/features/chat/model/conversation_model.dart';
import 'package:erp_mobile/features/chat/repository/chat_repository.dart';
import 'package:erp_mobile/features/chat/viewmodel/member_picker/member_picker_view_model_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

ContactModel person(String id, {String? name, bool enabled = true}) =>
    ContactModel(
      id: id,
      email: 'user$id@company.com',
      fullName: name ?? 'User $id',
      enabled: enabled,
    );

PageModel<ContactModel> pageOf(
  List<ContactModel> items, {
  int page = 1,
  int totalPages = 1,
}) => PageModel(
  items: items,
  page: page,
  pageSize: 100,
  totalItems: 0,
  totalPages: totalPages,
);

void main() {
  late _MockChatRepository repo;

  setUp(() {
    repo = _MockChatRepository();
    when(repo.myUserId).thenAnswer((_) async => '1');
  });

  List<String> ids(MemberPickerViewModelState s) => [
    for (final c in s.data!.contacts) c.id,
  ];

  blocTest<MemberPickerViewModelBloc, MemberPickerViewModelState>(
    'loads EVERY page; hides me, disabled accounts and people already in',
    setUp: () {
      when(() => repo.loadContacts(page: 1)).thenAnswer(
        (_) async => Right(
          pageOf([
            person('1'),
            person('2'),
            person('3', enabled: false),
          ], totalPages: 2),
        ),
      );
      when(() => repo.loadContacts(page: 2)).thenAnswer(
        (_) async =>
            Right(pageOf([person('4'), person('5')], page: 2, totalPages: 2)),
      );
    },
    build: () => MemberPickerViewModelBloc(repo, excludeIds: {'5'}),
    act: (bloc) => bloc.add(OnPickerLoadEvent()),
    expect: () => [
      isA<MemberPickerLoadingState>(),
      isA<MemberPickerLoadedState>()
          .having(ids, 'page 1', ['2'])
          .having((s) => s.isLoadingMore, 'more coming', true),
      isA<MemberPickerLoadedState>()
          .having(ids, 'all', ['2', '4'])
          .having((s) => s.isLoadingMore, 'done', false),
    ],
  );

  blocTest<MemberPickerViewModelBloc, MemberPickerViewModelState>(
    'search filters on the phone by name OR email',
    build: () => MemberPickerViewModelBloc(repo),
    seed: () => MemberPickerLoadedState(
      contacts: [
        person('2', name: 'Dara Sok'),
        person('3', name: 'Jane Doe'),
      ],
    ),
    act: (bloc) => bloc.add(OnPickerSearchEvent('dara')),
    verify: (bloc) => expect(bloc.state.data!.visible.map((c) => c.id), ['2']),
  );

  test('ContactModel.matches: name or email, any case, blank = all', () {
    final c = person('3', name: 'Jane Doe');
    expect(c.matches('JANE'), isTrue);
    expect(c.matches('user3@'), isTrue);
    expect(c.matches('  '), isTrue);
    expect(c.matches('dara'), isFalse);
  });

  blocTest<MemberPickerViewModelBloc, MemberPickerViewModelState>(
    'toggle adds, toggling again removes',
    build: () => MemberPickerViewModelBloc(repo),
    seed: () => MemberPickerLoadedState(contacts: [person('2'), person('3')]),
    act: (bloc) => bloc
      ..add(OnPickerToggleEvent(person('2')))
      ..add(OnPickerToggleEvent(person('3')))
      ..add(OnPickerToggleEvent(person('2'))),
    verify: (bloc) => expect(bloc.state.data!.selected.map((c) => c.id), ['3']),
  );

  blocTest<MemberPickerViewModelBloc, MemberPickerViewModelState>(
    'tap a person → createDirect → Done(conversation)',
    setUp: () => when(() => repo.createDirect('2')).thenAnswer(
      (_) async => const Right(
        ConversationModel(id: '9', type: ConversationType.direct),
      ),
    ),
    build: () => MemberPickerViewModelBloc(repo),
    seed: () => MemberPickerLoadedState(contacts: [person('2')]),
    act: (bloc) => bloc.add(OnPickerCreateDirectEvent(person('2'))),
    expect: () => [
      isA<MemberPickerLoadedState>().having(
        (s) => s.isSubmitting,
        'busy',
        true,
      ),
      isA<MemberPickerDoneState>().having((s) => s.conversation.id, 'id', '9'),
    ],
  );

  blocTest<MemberPickerViewModelBloc, MemberPickerViewModelState>(
    'create group fails → SubmitFailed (list + selection kept)',
    setUp: () => when(
      () => repo.createGroup(name: 'Team', memberIds: ['2']),
    ).thenAnswer((_) async => const Left(NoInternetError())),
    build: () => MemberPickerViewModelBloc(repo),
    seed: () => MemberPickerLoadedState(
      contacts: [person('2')],
      selected: [person('2')],
    ),
    act: (bloc) => bloc.add(OnPickerCreateGroupEvent('Team')),
    expect: () => [
      isA<MemberPickerLoadedState>().having(
        (s) => s.isSubmitting,
        'busy',
        true,
      ),
      isA<MemberPickerSubmitFailedState>()
          .having((s) => s.data.selected.length, 'kept', 1)
          .having((s) => s.data.isSubmitting, 'not busy', false),
    ],
  );

  blocTest<MemberPickerViewModelBloc, MemberPickerViewModelState>(
    'empty group name / nobody ticked → nothing sent',
    build: () => MemberPickerViewModelBloc(repo),
    seed: () => MemberPickerLoadedState(contacts: [person('2')]),
    act: (bloc) => bloc
      ..add(OnPickerCreateGroupEvent('Team')) // nobody ticked
      ..add(OnPickerAddMembersEvent('7')),
    expect: () => <MemberPickerViewModelState>[],
  );
}
