import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../di/injection.dart';
import '../error/failure.dart';
import '../error/failure_from_dio.dart';
import 'check_internet_service.dart';
import 'helper_service.dart';
import 'network_error_model.dart';

export 'helper_service.dart' show HttpMethods, HttpResponse;
export 'network_error_model.dart' show NetworkErrorModel;

/// One-call HTTP helper (same calling style as the MVVM template's
/// `AppService`), built on the app's **shared** `Dio`:
///
/// - base URL from the build flavor, `/api/v1` included;
/// - `Authorization: Bearer …` from secure storage, refreshed once on 401
///   and retried automatically (`AuthInterceptor`);
/// - any **2xx** is success (`201 Created`, `204 No Content` too);
/// - errors become a translated [NetworkErrorModel] (typed `Failure` inside).
///
/// ```dart
/// final result = await AppService(
///   httpMethods: HttpMethods.get,
///   endPoint: ApiEndPoint.streamToken,
/// ).send();
///
/// result.fold(
///   (error) => emit(state.copyWith(status: AppStatus.failure, error: error)),
///   (res) => emit(state.copyWith(token: res.data['token'] as String)),
/// );
///
/// // POST JSON body + query string:
/// await AppService(
///   httpMethods: HttpMethods.post,
///   endPoint: ApiEndPoint.conversationMessages(12),
///   data: {'type': 'TEXT', 'body': 'Hello'},
/// ).send();
/// ```
///
/// Paths come from `ApiEndPoint` (core/network/api_endpoints.dart).
class AppService {
  AppService({
    required this.httpMethods,
    required this.endPoint,
    this.data,
    this.queryParameters,
    this.formData,
    this.cancelToken,
    Dio? dio,
  }) : _dio = dio;

  final HttpMethods httpMethods;

  /// Relative path, e.g. `ApiEndPoint.conversations`.
  final String endPoint;

  /// JSON request body (POST / PUT / PATCH / DELETE).
  final Object? data;

  /// URL query string (`?page=1&pageSize=30`).
  final Map<String, dynamic>? queryParameters;

  /// Multipart body (file upload). Wins over [data] when both are set.
  final FormData? formData;

  final CancelToken? cancelToken;

  /// Test seam; production uses the shared DI `Dio`.
  final Dio? _dio;

  Future<Either<NetworkErrorModel, HttpResponse>> send() async {
    final dio = _dio ?? getIt<Dio>();
    final body = formData ?? data;
    try {
      final Response<dynamic> response = switch (httpMethods) {
        HttpMethods.get => await dio.get<dynamic>(endPoint,
            queryParameters: queryParameters, cancelToken: cancelToken),
        HttpMethods.post => await dio.post<dynamic>(endPoint,
            data: body,
            queryParameters: queryParameters,
            cancelToken: cancelToken),
        HttpMethods.put => await dio.put<dynamic>(endPoint,
            data: body,
            queryParameters: queryParameters,
            cancelToken: cancelToken),
        HttpMethods.patch => await dio.patch<dynamic>(endPoint,
            data: body,
            queryParameters: queryParameters,
            cancelToken: cancelToken),
        HttpMethods.delete => await dio.delete<dynamic>(endPoint,
            data: body,
            queryParameters: queryParameters,
            cancelToken: cancelToken),
      };
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        return Right(HttpResponse(response: response));
      }
      return Left(NetworkErrorModel.fromFailure(
          Failure.server(statusCode: code)));
    } on DioException catch (e) {
      final failure = failureFromDioException(e);
      // Connection-level errors: confirm the device is really offline so the
      // UI can say "No internet" instead of a generic error.
      if (failure is UnknownFailure &&
          !await CheckInternetService.checkDataConnection()) {
        return Left(NetworkErrorModel.fromFailure(const Failure.network()));
      }
      return Left(NetworkErrorModel.fromFailure(failure));
    } catch (e) {
      return Left(NetworkErrorModel.fromFailure(
          Failure.unknown(message: e.toString())));
    }
  }
}
