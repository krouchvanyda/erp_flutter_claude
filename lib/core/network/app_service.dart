import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:dio/dio.dart';

import '../utils/constants.dart';
import 'api_envelope.dart';
import 'check_internet_service.dart';
import 'helper_service.dart';
import 'network_error_model.dart';

/// Turns raw JSON `data` into your model, e.g. `UserModel.fromData`.
typedef Parser<T> = T Function(Object? data);

/// The ONE way repositories talk to the backend (MVVM-template style).
///
/// ```dart
/// final result = await appService.send(
///   httpMethods: HttpMethods.get,
///   endPoint: ApiEndPoint.me,
///   parse: UserModel.fromData,
/// );
/// result.fold(
///   (error) => emit(LoadMeErrorState(error: error)),
///   (user)  => emit(LoadMeLoadedState(user: user)),
/// );
/// ```
///
/// Differences from the template's `AppService`, and why:
/// - ONE shared [Dio] is injected (not `Dio()` per call) → interceptors
///   (logger, token refresh in Step 2.2) live in one place, and tests can pass
///   a fake.
/// - The backend envelope is unwrapped here; [parse] gets only `data`.
/// - Any 2xx is success (the template accepted only 200).
/// - No token code here: the auth interceptor (Step 2.2) adds it.
/// - Never throws: every problem becomes a [NetworkErrorModel] in `Left`.
class AppService {
  AppService(
    this._dio, {
    Future<bool> Function() hasInternet =
        CheckInternetService.checkDataConnection,
  }) : _hasInternet = hasInternet;

  final Dio _dio;

  /// Injected so tests don't depend on the real network.
  final Future<bool> Function() _hasInternet;

  Future<Either<NetworkErrorModel, T>> send<T>({
    required HttpMethods httpMethods,
    required String endPoint,
    required Parser<T> parse,
    Object? data,
    Map<String, dynamic>? queryParameters,
    FormData? formData,
  }) async {
    try {
      final body = formData ?? data; // FormData = file uploads (multipart)
      final response = switch (httpMethods) {
        HttpMethods.get => await _dio.get<Object?>(
          endPoint,
          queryParameters: queryParameters,
        ),
        HttpMethods.post => await _dio.post<Object?>(
          endPoint,
          data: body,
          queryParameters: queryParameters,
        ),
        HttpMethods.put => await _dio.put<Object?>(
          endPoint,
          data: body,
          queryParameters: queryParameters,
        ),
        HttpMethods.patch => await _dio.patch<Object?>(
          endPoint,
          data: body,
          queryParameters: queryParameters,
        ),
        HttpMethods.delete => await _dio.delete<Object?>(
          endPoint,
          data: body,
          queryParameters: queryParameters,
        ),
      };

      final envelope = ApiEnvelope.tryParse(response.data);

      // Not an envelope (a plain JSON body) → give the raw JSON to the parser.
      if (envelope == null) return Right(parse(response.data));

      // 2xx but success:false → still an error.
      if (!envelope.success) {
        return Left(_serverError(envelope, response.statusCode));
      }
      return Right(parse(envelope.data));
    } on DioException catch (e) {
      return Left(await _fromDio(e));
    } catch (e) {
      // Our parser crashed (bad JSON shape, a bug) — never crash the UI.
      return Left(UnknownError(description: 'Could not read the response: $e'));
    }
  }

  Future<NetworkErrorModel> _fromDio(DioException e) async {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NoInternetError(
          title: Constants.timeout,
          description: Constants.serverTooSlow,
        );
      case DioExceptionType.connectionError:
        // Template idea: check the phone's internet to pick the message.
        final online = await _hasInternet();
        return online
            ? const NoInternetError(
                title: Constants.serverUnreachable,
                description: Constants.pleaseTryLater,
              )
            : const NoInternetError();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? Constants.codeUnknown;
        if (status == 401) return const UnauthorizedError();
        final envelope = ApiEnvelope.tryParse(e.response?.data);
        if (envelope != null) return _serverError(envelope, status);
        return ServerError(
          description: '${Constants.serverError} ($status).',
          statusCode: status,
        );
      case DioExceptionType.cancel:
        return const UnknownError(description: 'Request cancelled.');
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return UnknownError(
          description: e.message ?? Constants.somethingWentWrong,
        );
    }
  }

  ServerError _serverError(ApiEnvelope envelope, int? statusCode) {
    return ServerError(
      description: envelope.message.isEmpty
          ? Constants.somethingWentWrong
          : envelope.message,
      statusCode: statusCode ?? Constants.codeUnknown,
      errorCode: envelope.errorCode,
      fieldErrors: envelope.fieldErrors,
      traceId: envelope.traceId,
    );
  }
}
