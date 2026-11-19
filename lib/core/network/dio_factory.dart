import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/flavor.dart';

/// Builds the ONE [Dio] the whole app shares (registered in DI).
///
/// One Dio = one place for base URL, timeouts and interceptors. Step 2.2
/// adds the auth interceptor here.
Dio createDio(Flavor flavor) {
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
