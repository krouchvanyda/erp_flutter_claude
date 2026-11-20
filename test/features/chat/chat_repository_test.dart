import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:erp_mobile/core/network/api_endpoints.dart';
import 'package:erp_mobile/core/network/app_service.dart';
import 'package:erp_mobile/core/network/auth_tokens.dart';
import 'package:erp_mobile/core/network/token_storage.dart';
import 'package:erp_mobile/core/realtime/realtime_service.dart';
import 'package:erp_mobile/features/chat/repository/chat_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/network/auth_tokens_test.dart' show jwt;

class _FakeServer implements HttpClientAdapter {
  RequestOptions? last;
  Object? data;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'message': 'Success',
        'data': data,
        'errorCode': null,
        'traceId': 't',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeServer server;
  late TokenStorage storage;
  late ChatRepository repo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    server = _FakeServer();
    storage = TokenStorage(const FlutterSecureStorage());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    repo = ChatRepository(
      appService: AppService(dio, hasInternet: () async => true),
      tokenStorage: storage,
      realtime: RealtimeService(
        url: 'ws://test/ws',
        accessToken: () async => null, // never started in these tests
      ),
    );
  });

  test('loadInbox → GET conversations?page&pageSize → PageModel', () async {
    server.data = {
      'items': [
        {'id': 1, 'type': 'DIRECT'},
        {'id': 2, 'type': 'GROUP', 'name': 'Team'},
      ],
      'page': 2,
      'pageSize': 20,
      'totalItems': 22,
      'totalPages': 2,
    };

    final page = (await repo.loadInbox(
      page: 2,
    )).getOrElse(() => throw StateError('expected Right'));

    expect(server.last!.path, ApiEndPoint.conversations);
    expect(server.last!.queryParameters, {'page': 2, 'pageSize': 20});
    expect(page.items.map((c) => c.id), ['1', '2']);
    expect(page.hasMore, isFalse);
  });

  test('myUserId = sub of the saved access token; none → null', () async {
    expect(await repo.myUserId(), isNull);
    await storage.write(
      AuthTokens(accessToken: jwt({'sub': 7}), refreshToken: 'r'),
    );
    expect(await repo.myUserId(), '7');
  });

  // ─────────────── Step 5.2 ───────────────

  test('loadMessages → GET …/{id}/messages?page&pageSize=30', () async {
    server.data = {
      'items': [
        {
          'id': 9,
          'conversationId': 5,
          'senderId': 2,
          'type': 'TEXT',
          'body': 'hi',
        },
      ],
      'page': 1,
      'pageSize': 30,
      'totalItems': 1,
      'totalPages': 1,
    };

    final page = (await repo.loadMessages(
      '5',
    )).getOrElse(() => throw StateError('expected Right'));

    expect(server.last!.method, 'GET');
    expect(server.last!.path, '/api/v1/chats/conversations/5/messages');
    expect(server.last!.queryParameters, {'page': 1, 'pageSize': 30});
    expect(page.items.single.body, 'hi');
    expect(page.hasMore, isFalse);
  });

  test('sendText → POST {type: TEXT, body} → the saved message', () async {
    server.data = {
      'id': 10,
      'conversationId': 5,
      'senderId': 1,
      'type': 'TEXT',
      'body': 'Hello',
    };

    final sent = (await repo.sendText(
      '5',
      'Hello',
    )).getOrElse(() => throw StateError('expected Right'));

    expect(server.last!.method, 'POST');
    expect(server.last!.path, ApiEndPoint.messages('5'));
    expect(server.last!.data, {'type': 'TEXT', 'body': 'Hello'});
    expect(sent.id, '10');
  });

  test('markRead → POST …/read {lastReadMessageId: NUMBER}', () async {
    await repo.markRead('5', '42');

    expect(server.last!.method, 'POST');
    expect(server.last!.path, '/api/v1/chats/conversations/5/read');
    expect(server.last!.data, {'lastReadMessageId': 42}); // int, not "42"
  });

  // ─────────────── Step 5.4 ───────────────

  group('new chats + groups', () {
    const groupJson = {
      'id': 7,
      'type': 'GROUP',
      'name': 'Team',
      'members': [
        {'userId': 1, 'role': 'ADMIN'},
        {'userId': 2},
      ],
    };

    test('loadContacts → GET /users?page&pageSize=100', () async {
      server.data = {
        'items': [
          {'id': 2, 'email': 'd@x.com', 'fullName': 'Dara', 'enabled': true},
        ],
        'page': 1,
        'pageSize': 100,
        'totalItems': 1,
        'totalPages': 1,
      };

      final page = (await repo.loadContacts()).getOrElse(
        () => throw StateError('expected Right'),
      );

      expect(server.last!.path, ApiEndPoint.users);
      expect(server.last!.queryParameters, {'page': 1, 'pageSize': 100});
      expect(page.items.single.displayName, 'Dara');
    });

    test('createDirect → POST {type: DIRECT, memberIds: [number]}', () async {
      server.data = {'id': 3, 'type': 'DIRECT'};

      await repo.createDirect('2');

      expect(server.last!.method, 'POST');
      expect(server.last!.path, ApiEndPoint.conversations);
      expect(server.last!.data, {
        'type': 'DIRECT',
        'memberIds': [2],
      });
    });

    test(
      'createGroup → POST {type: GROUP, name (trimmed), memberIds}',
      () async {
        server.data = groupJson;

        final group = (await repo.createGroup(
          name: '  Team ',
          memberIds: ['2', '3'],
        )).getOrElse(() => throw StateError('expected Right'));

        expect(server.last!.data, {
          'type': 'GROUP',
          'name': 'Team',
          'memberIds': [2, 3],
        });
        expect(group.name, 'Team');
      },
    );

    test('rename → PATCH /conversations/{id} {name}', () async {
      server.data = groupJson;
      await repo.rename('7', 'New');
      expect(server.last!.method, 'PATCH');
      expect(server.last!.path, ApiEndPoint.conversation('7'));
      expect(server.last!.data, {'name': 'New'});
    });

    test('addMembers → POST …/members {memberIds}', () async {
      server.data = groupJson;
      await repo.addMembers('7', ['4']);
      expect(server.last!.path, '/api/v1/chats/conversations/7/members');
      expect(server.last!.data, {
        'memberIds': [4],
      });
    });

    test('leave → DELETE …/members/{MY id}', () async {
      await storage.write(
        AuthTokens(accessToken: jwt({'sub': 1}), refreshToken: 'r'),
      );
      server.data = groupJson;

      final result = await repo.leave('7');

      expect(result.isRight(), isTrue);
      expect(server.last!.method, 'DELETE');
      expect(server.last!.path, '/api/v1/chats/conversations/7/members/1');
    });

    test('deleteConversation → DELETE /conversations/{id}', () async {
      await repo.deleteConversation('7');
      expect(server.last!.method, 'DELETE');
      expect(server.last!.path, ApiEndPoint.conversation('7'));
    });
  });
}
