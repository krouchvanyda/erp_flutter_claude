import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/core/network/app_service.dart';
import 'package:erp_mobile/core/network/api_endpoints.dart';
import 'package:erp_mobile/localization/language.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [status] + [body], or throws [error].
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.status = 200, this.body, this.error});
  final int status;
  final Object? body;
  final DioExceptionType? error;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    if (error != null) {
      throw DioException(requestOptions: options, type: error!);
    }
    return ResponseBody.fromString(jsonEncode(body ?? {}), status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeAdapter a) =>
    Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = a;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => Language.init(Language.english));

  test('GET 200 → Right with the body', () async {
    final a = _FakeAdapter(body: {'token': 'abc'});
    final result = await AppService(
      httpMethods: HttpMethods.get,
      endPoint: ApiEndPoint.streamToken,
      dio: _dio(a),
    ).send();

    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected success'),
        (res) => expect(res.data['token'], 'abc'));
    expect(a.last!.method, 'GET');
    expect(a.last!.uri.toString(),
        'http://api.test/api/v1/chats/calls/stream-token');
  });

  test('POST 201 Created counts as success (template only accepted 200)',
      () async {
    final a = _FakeAdapter(status: 201, body: {'id': 345});
    final result = await AppService(
      httpMethods: HttpMethods.post,
      endPoint: ApiEndPoint.conversationMessages(12),
      data: {'type': 'TEXT', 'body': 'Hello'},
      dio: _dio(a),
    ).send();

    expect(result.isRight(), isTrue);
    expect(a.last!.method, 'POST');
    expect(a.last!.data, {'type': 'TEXT', 'body': 'Hello'});
  });

  test('GET with query parameters', () async {
    final a = _FakeAdapter();
    await AppService(
      httpMethods: HttpMethods.get,
      endPoint: ApiEndPoint.conversations,
      queryParameters: {'page': 1, 'pageSize': 30},
      dio: _dio(a),
    ).send();
    expect(a.last!.uri.queryParameters, {'page': '1', 'pageSize': '30'});
  });

  test('404 → Left NetworkErrorModel with NotFoundFailure', () async {
    final result = await AppService(
      httpMethods: HttpMethods.get,
      endPoint: ApiEndPoint.call(9),
      dio: _dio(_FakeAdapter(status: 404)),
    ).send();

    final error = result.fold((e) => e, (_) => null)!;
    expect(error.statusCode, 404);
    expect(error.failure, isA<NotFoundFailure>());
    expect(error.title, 'Not found');
  });

  test('timeout → Left with a translated timeout message', () async {
    final result = await AppService(
      httpMethods: HttpMethods.get,
      endPoint: ApiEndPoint.conversations,
      dio: _dio(_FakeAdapter(error: DioExceptionType.connectionTimeout)),
    ).send();

    final error = result.fold((e) => e, (_) => null)!;
    expect(error.failure, isA<TimeoutFailure>());
    expect(error.title, 'Request timed out');
  });

  test('NetworkErrorModel text follows the app language', () async {
    await Language.init(Language.khmer);
    final e = NetworkErrorModel.fromFailure(const Failure.network());
    expect(e.title, 'គ្មានអ៊ីនធឺណិត');
    expect(e.statusCode, NetworkErrorModel.codeNetwork);
    await Language.init(Language.english);
  });
}
