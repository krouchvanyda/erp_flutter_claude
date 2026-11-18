import 'package:dio/dio.dart';

/// HTTP verbs supported by [AppService] (template: `HttpMethods`).
enum HttpMethods { get, post, put, patch, delete }

/// Successful [AppService.send] result (template: `HttpResponse`).
///
/// [response] is the raw dio `Response`; read the body with
/// `httpResponse.response.data`.
class HttpResponse {
  const HttpResponse({required this.response, this.status = true});

  final Response<dynamic> response;
  final bool status;

  int? get statusCode => response.statusCode;
  dynamic get data => response.data;
}
