import 'package:dio/dio.dart';

import 'api_endpoints.dart';
import 'auth_tokens.dart';
import 'token_refresher.dart';
import 'token_storage.dart';

/// Adds the token to every request, and fixes an expired token by itself.
///
/// ```
/// request ─► onRequest: + Authorization: Bearer <accessToken>
/// 401     ─► onError:   refresh once ─► save new pair ─► retry the request
///                       refresh rejected ─► clear tokens ─► log out
/// ```
///
/// [QueuedInterceptor] = handles ONE request at a time in each step. If 3
/// requests get 401 together, the 1st refreshes; the 2nd and 3rd wait, then
/// see the token already changed and just retry — ONE refresh, not three.
/// (Our refresh token is rotated, so 3 parallel refreshes would make 2 fail.)
///
/// The refresh itself lives in [TokenRefresher] (Step 5.3), shared with the
/// realtime socket, so the two can never refresh at the same time.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required TokenRefresher refresher,
    required Dio retryDio,
  }) : _tokenStorage = tokenStorage,
       _refresher = refresher,
       _retryDio = retryDio;

  final TokenStorage _tokenStorage;
  final TokenRefresher _refresher;

  /// A SEPARATE Dio without this interceptor, for the retry — so it can
  /// never loop back into this interceptor.
  final Dio _retryDio;

  /// Marks a request we already retried once — never retry it again.
  static const String _retriedKey = 'auth.retried';

  static const String _header = 'Authorization';

  // ── Every request ───────────────────────────────────────────────
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!ApiEndPoint.isPublic(options.path)) {
      final tokens = await _tokenStorage.read();
      if (tokens != null) {
        options.headers[_header] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  // ── Every error ─────────────────────────────────────────────────
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;

    // Not our business: not a 401, a public endpoint (wrong password on
    // login is ALSO 401), or a request we already retried.
    if (err.response?.statusCode != 401 ||
        ApiEndPoint.isPublic(request.path) ||
        request.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final stored = await _tokenStorage.read();
    if (stored == null) {
      await _refresher.expireSession(); // no tokens → nothing to refresh
      return handler.next(err);
    }

    final AuthTokens fresh;
    if (request.headers[_header] != 'Bearer ${stored.accessToken}') {
      // Another queued request already refreshed while we waited.
      fresh = stored;
    } else {
      // Saves the new pair, or clears + logs out when refused (see
      // TokenRefresher).
      switch (await _refresher.refresh()) {
        case RefreshOk(:final tokens):
          fresh = tokens;
        case RefreshRejected():
          // Server says the refresh token is dead → the session is over.
          return handler.next(err);
        case RefreshFailed():
          // Offline / timeout during refresh → NOT the user's fault.
          // Keep the tokens; the user stays logged in and can retry.
          return handler.next(err);
      }
    }

    try {
      handler.resolve(await _retry(request, fresh));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────
  Future<Response<dynamic>> _retry(RequestOptions request, AuthTokens tokens) {
    final data = request.data;
    final options = request.copyWith(
      headers: {...request.headers, _header: 'Bearer ${tokens.accessToken}'},
      extra: {...request.extra, _retriedKey: true},
      // A FormData (file upload) can be sent only ONCE — its stream is used
      // up. Retrying the same object throws "already finalized" → send a
      // fresh copy (Step 4.2 avatar upload).
      data: data is FormData ? data.clone() : data,
    );
    return _retryDio.fetch<dynamic>(options);
  }
}
