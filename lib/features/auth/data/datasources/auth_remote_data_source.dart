import 'package:dio/dio.dart';

import '../../../../core/network/auth_interceptor.dart';

/// Auth-server data source surface. Slice 1.1.4 ships only the revoke
/// endpoint; subsequent slices (1.1.1 login form, 1.2.x SSO) extend the
/// same interface.
abstract class AuthRemoteDataSource {
  /// Best-effort server-side invalidation of [refreshToken] — call this
  /// from the sign-out path. May throw on transport / 4xx / 5xx; callers
  /// must treat any failure as a hint to *still* clean up locally so the
  /// user doesn't get stuck signed in when the server is unreachable.
  Future<void> revokeRefreshToken(String refreshToken);
}

/// `dio`-backed implementation. Uses a dedicated [Dio] (no auth /
/// error-mapping interceptors) so the call doesn't race the [AuthInterceptor]
/// during sign-out: a stale access token must not trigger a refresh while
/// the user is on their way out, and a 401 here must not loop.
///
/// Follows RFC 7009-style OAuth token revocation — the token to revoke is
/// the body payload; no Bearer header attached.
class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  DioAuthRemoteDataSource({required Dio dio}) : _dio = dio;

  /// Path resolved against `dio.options.baseUrl`.
  static const String revokePath = '/auth/logout';

  // Body key for the OAuth revoke convention.
  static const String _bodyRefreshToken = 'refresh_token';

  final Dio _dio;

  @override
  Future<void> revokeRefreshToken(String refreshToken) async {
    await _dio.post<dynamic>(
      revokePath,
      data: <String, String>{_bodyRefreshToken: refreshToken},
      options: Options(
        extra: const <String, dynamic>{AuthInterceptor.skipAuthKey: true},
      ),
    );
  }
}
