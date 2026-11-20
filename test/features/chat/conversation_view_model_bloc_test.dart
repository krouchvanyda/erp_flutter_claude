import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/network/page_model.dart';
import 'package:erp_mobile/features/chat/model/chat_attachment.dart';
import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/chat_update.dart';
import 'package:erp_mobile/features/chat/model/message_model.dart';
import 'package:erp_mobile/features/chat/repository/chat_repository.dart';
import 'package:erp_mobile/features/chat/viewmodel/conversation/conversation_view_model_bloc.dart';
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
  late StreamController<ChatUpdate> updates;
  late StreamController<void> reconnected;
  late Completer<void> gate;

  setUp(() {
    repo = _MockChatRepository();
    updates = StreamController<ChatUpdate>.broadcast();
    reconnected = StreamController<void>.broadcast();
    when(
      () => repo.conversationUpdates(any()),
    ).thenAnswer((_) => updates.stream);
    when(() => repo.reconnected).thenAnswer((_) => reconnected.stream);
    when(
      () => repo.markRead(any(), any()),
    ).thenAnswer((_) async => const Right(null));
  });

  ConversationViewModelBloc build() =>
      ConversationViewModelBloc(repo, conversationId: 'c1', myId: '1');

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

  // ─────────────── Step 5.3: live ───────────────

  group('live', () {
    blocTest<ConversationViewModelBloc, ConversationViewModelState>(
      'someone writes → new bubble at the bottom + marked read',
      build: build,
      seed: () => loaded(['3']),
      act: (_) => updates.add(MessageArrived(msg('4', body: 'yo'))),
      expect: () => [
        isA<ConversationLoadedState>().having(
          (s) => s.messages.map((m) => m.id),
          'ids',
          ['4', '3'],
        ),
      ],
      verify: (_) => verify(() => repo.markRead('c1', '4')).called(1),
    );

    blocTest<ConversationViewModelBloc, ConversationViewModelState>(
      'my own echo arrives BEFORE the HTTP answer → replaces the 🕓 bubble, no double',
      setUp: () {
        gate = Completer<void>();
        when(() => repo.sendText('c1', 'Hi')).thenAnswer((_) async {
          await gate.future;
          return Right(msg('4', sender: '1', body: 'Hi'));
        });
      },
      build: build,
      seed: () => loaded(['3']),
      act: (bloc) async {
        bloc.add(OnMessageSendEvent('Hi'));
        await Future<void>.delayed(Duration.zero);
        updates.add(MessageArrived(msg('4', sender: '1', body: 'Hi'))); // echo
        await Future<void>.delayed(Duration.zero);
        gate.complete(); // then the HTTP answer
      },
      verify: (bloc) {
        final data = bloc.state.data!;
        expect(data.outgoing, isEmpty);
        expect(data.messages.map((m) => m.id), ['4', '3']); // once
        verifyNever(() => repo.markRead('c1', '4')); // mine: no read call
      },
    );

    blocTest<ConversationViewModelBloc, ConversationViewModelState>(
      'message.read → my messages up to that id get ✓✓ (theirs do not)',
      build: build,
      seed: () => ConversationLoadedState(
        messages: [
          msg('12', sender: '1'),
          msg('11', sender: '1'),
          msg('9', sender: '1'),
          msg('8'),
        ],
        page: 1,
        hasMore: false,
      ),
      act: (_) => updates.add(
        const MessagesRead(
          conversationId: 'c1',
          userId: '2',
          lastReadMessageId: '11',
        ),
      ),
      verify: (bloc) {
        final read = {
          for (final m in bloc.state.data!.messages)
            m.id: m.readByUserIds.contains('2'),
        };
        // '9' < '11' as NUMBERS (as text "9" > "11")
        expect(read, {'12': false, '11': true, '9': true, '8': false});
      },
    );

    blocTest<ConversationViewModelBloc, ConversationViewModelState>(
      'edit keeps the ✓✓ we already know',
      build: build,
      seed: () => ConversationLoadedState(
        messages: [
          msg('5', sender: '1').copyWith(readByUserIds: {'2'}),
        ],
        page: 1,
        hasMore: false,
      ),
      act: (_) =>
          updates.add(MessageChanged(msg('5', sender: '1', body: 'edited'))),
      verify: (bloc) {
        final m = bloc.state.data!.messages.single;
        expect(m.body, 'edited');
        expect(m.readByUserIds, {'2'});
      },
    );

    blocTest<ConversationViewModelBloc, ConversationViewModelState>(
      'connection back → reload (catch-up)',
      setUp: () => when(
        () => repo.loadMessages('c1'),
      ).thenAnswer((_) async => Right(pageOf(['3']))),
      build: build,
      seed: () => loaded(['3']),
      act: (_) => reconnected.add(null),
      verify: (_) => verify(() => repo.loadMessages('c1')).called(1),
    );
  });

  // ─────────────── Step 5.5: attachments ───────────────

  group('attachments', () {
    const uploaded = ChatAttachmentModel(
      url: '/uploads/chat/a.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 300,
    );
    MessageModel imageMsg(String id) => MessageModel(
      id: id,
      conversationId: 'c1',
      senderId: '1',
      type: MessageType.image,
      attachmentUrl: uploaded.url,
    );

    setUpAll(() {
      registerFallbackValue(MessageType.text);
      registerFallbackValue(uploaded);
    });

    void stubUpload(
      Future<Either<NetworkErrorModel, ChatAttachmentModel>> Function() answer,
    ) => when(
      () => repo.uploadAttachment(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) => answer());

    void stubSend(
      Future<Either<NetworkErrorModel, MessageModel>> Function() answer,
    ) => when(
      () => repo.sendAttachment(
        any(),
        type: any(named: 'type'),
        attachment: any(named: 'attachment'),
        durationSeconds: any(named: 'durationSeconds'),
      ),
    ).thenAnswer((_) => answer());

    blocTest<ConversationViewModelBloc, ConversationViewModelState>(
      'photo: shows at once (local file) → upload → send → server message',
      setUp: () {
        stubUpload(() async => const Right(uploaded));
        stubSend(() async => Right(imageMsg('20')));
      },
      build: build,
      seed: () => loaded(['3']),
      act: (bloc) => bloc.add(
        OnAttachmentSendEvent(type: MessageType.image, filePath: '/tmp/a.jpg'),
      ),
      verify: (bloc) {
        final data = bloc.state.data!;
        expect(data.outgoing, isEmpty);
        expect(data.messages.first.id, '20');
        verify(
          () => repo.sendAttachment(
            'c1',
            type: MessageType.image,
            attachment: uploaded,
            durationSeconds: null,
          ),
        ).called(1);
      },
    );

    blocTest<ConversationViewModelBloc, ConversationViewModelState>(
      'the first state is the optimistic bubble with the LOCAL path',
      setUp: () {
        stubUpload(
          () => Completer<Either<NetworkErrorModel, ChatAttachmentModel>>()
              .future, // never finishes
        );
      },
      build: build,
      seed: () => loaded(['3']),
      act: (bloc) => bloc.add(
        OnAttachmentSendEvent(type: MessageType.image, filePath: '/tmp/a.jpg'),
      ),
      expect: () => [
        isA<ConversationLoadedState>()
            .having((s) => s.outgoing.single.localPath, 'path', '/tmp/a.jpg')
            .having((s) => s.outgoing.single.progress, 'progress', 0.0),
      ],
    );

    blocTest<ConversationViewModelBloc, ConversationViewModelState>(
      'upload OK but message fails → retry does NOT upload again',
      setUp: () {
        var sends = 0;
        stubUpload(() async => const Right(uploaded));
        stubSend(
          () async => ++sends == 1
              ? const Left(NoInternetError())
              : Right(imageMsg('21')),
        );
      },
      build: build,
      seed: () => loaded(['3']),
      act: (bloc) async {
        bloc.add(
          OnAttachmentSendEvent(
            type: MessageType.image,
            filePath: '/tmp/a.jpg',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(bloc.state.data!.outgoing.single.failed, isTrue);
        expect(bloc.state.data!.outgoing.single.uploadedUrl, uploaded.url);
        bloc.add(OnMessageRetryEvent('local-1'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        verify(
          () => repo.uploadAttachment(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1); // once
        expect(bloc.state.data!.messages.first.id, '21');
        expect(bloc.state.data!.outgoing, isEmpty);
      },
    );

    blocTest<ConversationViewModelBloc, ConversationViewModelState>(
      'upload fails → bubble ⚠ (no message request)',
      setUp: () => stubUpload(() async => const Left(NoInternetError())),
      build: build,
      seed: () => loaded(['3']),
      act: (bloc) => bloc.add(
        OnAttachmentSendEvent(type: MessageType.file, filePath: '/tmp/r.pdf'),
      ),
      verify: (bloc) {
        final o = bloc.state.data!.outgoing.single;
        expect((o.failed, o.progress, o.uploadedUrl), (true, null, null));
        verifyNever(
          () => repo.sendAttachment(
            any(),
            type: any(named: 'type'),
            attachment: any(named: 'attachment'),
            durationSeconds: any(named: 'durationSeconds'),
          ),
        );
      },
    );

    blocTest<ConversationViewModelBloc, ConversationViewModelState>(
      'my echo of a photo replaces the bubble by its uploaded URL',
      setUp: () {
        gate = Completer<void>();
        stubUpload(() async => const Right(uploaded));
        stubSend(() async {
          await gate.future;
          return Right(imageMsg('22'));
        });
      },
      build: build,
      seed: () => loaded(['3']),
      act: (bloc) async {
        bloc.add(
          OnAttachmentSendEvent(
            type: MessageType.image,
            filePath: '/tmp/a.jpg',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        updates.add(MessageArrived(imageMsg('22'))); // echo first
        await Future<void>.delayed(Duration.zero);
        gate.complete();
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        final data = bloc.state.data!;
        expect(data.outgoing, isEmpty);
        expect(data.messages.where((m) => m.id == '22'), hasLength(1));
      },
    );
  });
}
