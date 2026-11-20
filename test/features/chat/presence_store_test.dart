import 'dart:async';

import 'package:dartz/dartz.dart' show Right;
import 'package:erp_mobile/core/router/auth_session.dart';
import 'package:erp_mobile/features/chat/model/presence_model.dart';
import 'package:erp_mobile/features/chat/repository/chat_repository.dart';
import 'package:erp_mobile/features/chat/repository/presence_store.dart';
import 'package:erp_mobile/features/chat/widgets/conversation_app_bar_title.dart';
import 'package:erp_mobile/core/utils/chat_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

PresenceModel p(String id, PresenceStatus s) =>
    PresenceModel(userId: id, status: s);

void main() {
  late _MockChatRepository repo;
  late StreamController<PresenceModel> live;
  late StreamController<void> reconnected;
  late AuthSession session;
  late List<Set<String>> asked;

  setUp(() {
    repo = _MockChatRepository();
    live = StreamController<PresenceModel>.broadcast();
    reconnected = StreamController<void>.broadcast();
    session = AuthSession()..markAuthenticated();
    asked = [];
    when(repo.presenceUpdates).thenAnswer((_) => live.stream);
    when(() => repo.reconnected).thenAnswer((_) => reconnected.stream);
    when(() => repo.loadPresence(any())).thenAnswer((i) async {
      final ids = (i.positionalArguments.first as Iterable<String>).toSet();
      asked.add(ids);
      return Right([for (final id in ids) p(id, PresenceStatus.online)]);
    });
  });

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('watch loads only people not known yet (one request)', () async {
    final store = PresenceStore(repo, session: session);
    await store.watch(['2', '3']);
    await store.watch(['3', '4']);
    expect(asked, [
      {'2', '3'},
      {'4'},
    ]);
    expect(store.of('4')?.isOnline, isTrue);
  });

  test('live update changes a watched person; others are ignored', () async {
    final store = PresenceStore(repo, session: session);
    await store.watch(['2']);
    live
      ..add(p('2', PresenceStatus.busy))
      ..add(p('99', PresenceStatus.online)); // not shown anywhere
    await tick();
    expect(store.of('2')?.status, PresenceStatus.busy);
    expect(store.of('99'), isNull);
  });

  test('reconnected → reload everyone watched (we missed updates)', () async {
    final store = PresenceStore(repo, session: session);
    await store.watch(['2', '3']);
    reconnected.add(null);
    await tick();
    expect(asked.last, {'2', '3'});
  });

  test('logout → forget everything', () async {
    final store = PresenceStore(repo, session: session);
    await store.watch(['2']);
    session.markLoggedOut();
    expect(store.presence.value, isEmpty);
  });

  test('presenceLine + ChatTime.lastSeen', () {
    final now = DateTime(2026, 11, 20, 12);
    expect(presenceLine(p('2', PresenceStatus.online)), 'online');
    expect(presenceLine(p('2', PresenceStatus.busy)), 'in a call');
    expect(presenceLine(null), isNull);
    expect(
      presenceLine(
        PresenceModel(
          userId: '2',
          status: PresenceStatus.offline,
          lastSeenAt: DateTime(2026, 11, 20, 10, 42),
        ),
        now: now,
      ),
      'last seen 10:42',
    );
    expect(
      ChatTime.lastSeen(now.subtract(const Duration(seconds: 20)), now: now),
      'last seen just now',
    );
    expect(
      ChatTime.lastSeen(DateTime(2026, 11, 19, 22, 10), now: now),
      'last seen yesterday 22:10',
    );
    expect(
      ChatTime.lastSeen(DateTime(2026, 11, 2), now: now),
      'last seen 2 Nov',
    );
    expect(PresenceStatus.fromJson('WEIRD'), PresenceStatus.offline);
  });
}
