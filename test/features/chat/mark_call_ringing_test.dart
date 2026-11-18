import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:erp_mobile/features/chat/repositories/chats_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers with [body]; records the last request.
class _Fake implements HttpClientAdapter {
  _Fake(this.body);
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
      Future<void>? __) async {
    last = o;
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

DioChatsRemoteDataSource _remote(_Fake f) => DioChatsRemoteDataSource(
    dio: Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
      ..httpClientAdapter = f);

void main() {
  test('POST /chats/calls/{id}/ringing → notified true', () async {
    final fake = _Fake({
      'success': true,
      'data': {'callId': 8, 'notified': true},
    });
    expect(await _remote(fake).markCallRinging(8), isTrue);
    expect(fake.last!.method, 'POST');
    expect(fake.last!.path, '/chats/calls/8/ringing');
  });

  test('late report (call already answered/ended) → false', () async {
    final fake = _Fake({
      'success': true,
      'data': {'callId': 8, 'notified': false},
    });
    expect(await _remote(fake).markCallRinging(8), isFalse);
  });
}
