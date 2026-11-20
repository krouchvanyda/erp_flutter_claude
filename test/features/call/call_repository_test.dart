import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:erp_mobile/core/network/api_endpoints.dart';
import 'package:erp_mobile/core/network/app_service.dart';
import 'package:erp_mobile/core/network/token_storage.dart';
import 'package:erp_mobile/core/realtime/realtime_service.dart';
import 'package:erp_mobile/features/call/model/call_enums.dart';
import 'package:erp_mobile/features/call/repository/call_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with the envelope around [data], and remembers it.
class _FakeServer implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Object? data = const {'id': 7, 'conversationId': 42, 'status': 'RINGING'};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'ok', 'data': data}),
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
  late CallRepository repo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    server = _FakeServer();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    repo = CallRepository(
      appService: AppService(dio, hasInternet: () async => true),
      tokenStorage: TokenStorage(const FlutterSecureStorage()),
      realtime: RealtimeService(
        url: 'ws://test/ws',
        accessToken: () async => null, // never started here
      ),
    );
  });

  test('start → POST /conversations/{id}/calls {type: VIDEO}', () async {
    final call = (await repo.start(
      '42',
      CallType.video,
    )).getOrElse(() => throw StateError('expected Right'));
    final r = server.requests.single;
    expect(r.method, 'POST');
    expect(r.path, '/api/v1/chats/conversations/42/calls');
    expect(r.data, {'type': 'VIDEO'});
    expect(call.id, '7');
  });

  test('ringing / accept / end → POST /calls/{id}/…', () async {
    await repo.ringing('7');
    await repo.accept('7');
    await repo.end('7');
    expect(server.requests.map((r) => '${r.method} ${r.path}'), [
      'POST ${ApiEndPoint.callRinging('7')}',
      'POST /api/v1/chats/calls/7/accept',
      'POST /api/v1/chats/calls/7/end',
    ]);
  });

  test('reject: ?reason=busy only when given', () async {
    await repo.reject('7');
    await repo.reject('8', reason: 'busy');
    expect(server.requests[0].path, '/api/v1/chats/calls/7/reject');
    expect(server.requests[0].queryParameters, isEmpty);
    expect(server.requests[1].queryParameters, {'reason': 'busy'});
  });

  test('load → GET /calls/{id}', () async {
    await repo.load('7');
    expect(server.requests.single.method, 'GET');
    expect(server.requests.single.path, '/api/v1/chats/calls/7');
  });

  test('destinations', () {
    expect(ApiEndPoint.callsQueue, '/user/queue/calls');
    expect(ApiEndPoint.callTopic('42'), '/topic/conversations/42/call');
  });
}
