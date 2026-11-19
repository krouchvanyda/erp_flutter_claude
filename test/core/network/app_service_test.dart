import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:erp_mobile/core/network/api_endpoints.dart';
import 'package:erp_mobile/core/network/app_service.dart';
import 'package:erp_mobile/core/network/helper_service.dart';
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake "server": returns whatever the test sets, no real network.
class _FakeAdapter implements HttpClientAdapter {
  int status = 200;
  Object? body;
  DioExceptionType? throwType;
  String? lastMethod;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastMethod = options.method;
    if (throwType != null) {
      throw DioException(requestOptions: options, type: throwType!);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> envelope({
  bool success = true,
  String message = 'Success',
  Object? data,
  String? errorCode,
}) => {
  'success': success,
  'message': message,
  'data': data,
  'errorCode': errorCode,
  'traceId': 't-1',
};

void main() {
  late _FakeAdapter server;
  late bool phoneOnline;
  late AppService appService;

  setUp(() {
    server = _FakeAdapter();
    phoneOnline = false;
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    appService = AppService(dio, hasInternet: () async => phoneOnline);
  });

  String parseName(Object? data) =>
      (data as Map<String, dynamic>)['name'] as String;

  Future<NetworkErrorModel> errorOf(HttpMethods method) async {
    final result = await appService.send(
      httpMethods: method,
      endPoint: '/x',
      parse: parseName,
    );
    return result.fold((e) => e, (_) => throw StateError('expected Left'));
  }

  test('success envelope → Right(parsed data)', () async {
    server.body = envelope(data: {'name': 'Vanyda'});

    final result = await appService.send(
      httpMethods: HttpMethods.get,
      endPoint: '/x',
      parse: parseName,
    );

    expect(result.getOrElse(() => ''), 'Vanyda');
  });

  test('201 Created is success too (template only accepted 200)', () async {
    server
      ..status = 201
      ..body = envelope(data: {'name': 'New'});

    final result = await appService.send(
      httpMethods: HttpMethods.post,
      endPoint: '/x',
      parse: parseName,
    );

    expect(result.getOrElse(() => ''), 'New');
  });

  test('HttpMethods maps to the right HTTP verb', () async {
    server.body = envelope(data: {'name': 'x'});
    for (final (method, verb) in [
      (HttpMethods.get, 'GET'),
      (HttpMethods.post, 'POST'),
      (HttpMethods.put, 'PUT'),
      (HttpMethods.patch, 'PATCH'),
      (HttpMethods.delete, 'DELETE'),
    ]) {
      await appService.send(
        httpMethods: method,
        endPoint: '/x',
        parse: parseName,
      );
      expect(server.lastMethod, verb);
    }
  });

  test('not an envelope (plain JSON) → parser gets raw JSON', () async {
    server.body = {'status': 'UP'};

    final result = await appService.send(
      httpMethods: HttpMethods.get,
      endPoint: '/health',
      parse: (d) => (d as Map<String, dynamic>)['status'] as String,
    );

    expect(result.getOrElse(() => ''), 'UP');
  });

  test('2xx but success:false → ServerError', () async {
    server.body = envelope(success: false, message: 'Nope', errorCode: 'X');

    final error = await errorOf(HttpMethods.get) as ServerError;

    expect(error.description, 'Nope');
    expect(error.errorCode, 'X');
  });

  test('400 with fieldErrors → ServerError with field messages', () async {
    server
      ..status = 400
      ..body = envelope(
        success: false,
        message: 'Validation failed',
        errorCode: 'VALIDATION_ERROR',
        data: {
          'fieldErrors': {'email': 'must be a valid email'},
        },
      );

    final error = await errorOf(HttpMethods.post) as ServerError;

    expect(error.statusCode, 400);
    expect(error.fieldErrors, {'email': 'must be a valid email'});
  });

  test('401 → UnauthorizedError', () async {
    server
      ..status = 401
      ..body = envelope(success: false, message: 'Unauthorized');

    expect(await errorOf(HttpMethods.get), isA<UnauthorizedError>());
  });

  test('401 on LOGIN → ServerError with the server message '
      '(not "Session expired")', () async {
    server
      ..status = 401
      ..body = envelope(
        success: false,
        message: 'Invalid email or password',
        errorCode: 'UNAUTHORIZED',
      );

    final result = await appService.send(
      httpMethods: HttpMethods.post,
      endPoint: ApiEndPoint.login,
      parse: parseName,
    );
    final error = result.fold((e) => e, (_) => throw StateError('Left'));

    expect(error, isA<ServerError>());
    expect(error.title, Constants.error);
    expect(error.description, 'Invalid email or password');
    expect(error.statusCode, 401);
    expect((error as ServerError).errorCode, 'UNAUTHORIZED');
  });

  test('500 without envelope → ServerError(500)', () async {
    server
      ..status = 500
      ..body = 'oops';

    expect((await errorOf(HttpMethods.get)).statusCode, 500);
  });

  test('connection error + phone offline → "No Internet"', () async {
    server.throwType = DioExceptionType.connectionError;
    phoneOnline = false;

    final error = await errorOf(HttpMethods.get);

    expect(error, isA<NoInternetError>());
    expect(error.title, Constants.noInternet);
    expect(error.statusCode, Constants.codeNetwork);
  });

  test('connection error + phone online → "Server unreachable"', () async {
    server.throwType = DioExceptionType.connectionError;
    phoneOnline = true;

    final error = await errorOf(HttpMethods.get);

    expect(error.title, Constants.serverUnreachable);
  });

  test('timeout → NoInternetError with "Timeout" title', () async {
    server.throwType = DioExceptionType.receiveTimeout;

    expect((await errorOf(HttpMethods.get)).title, Constants.timeout);
  });

  test('parser crashes on a bad shape → UnknownError (no throw)', () async {
    server.body = envelope(data: 'not a map');

    expect(await errorOf(HttpMethods.get), isA<UnknownError>());
  });
}
