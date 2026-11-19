import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/flavor.dart';

/// Builds a [Dio] with our base URL, timeouts and logger.
///
/// DI builds TWO:
/// - the app Dio: `createDio(flavor, interceptors: [AuthInterceptor(...)])`
/// - the refresh Dio: `createDio(flavor)` — no auth interceptor, used only for
///   the refresh call + retry, so they can never loop.
Dio createDio(Flavor flavor, {List<Interceptor> interceptors = const []}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: flavor.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15), // open the connection
      sendTimeout: const Duration(seconds: 15), // upload the request
      receiveTimeout: const Duration(seconds: 30), // wait for the answer
      headers: {Headers.acceptHeader: Headers.jsonContentType},
      contentType: Headers.jsonContentType,
    ),
  );

  // Ours first (auth adds the token), then the logger.
  dio.interceptors.addAll(interceptors);

  if (flavor.enableNetworkLogging) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestBody: true,
        responseBody: true,
        // Never print the Authorization header (tokens) — even in dev.
        requestHeader: false,
        compact: true,
      ),
    );
  }
  return dio;
}
