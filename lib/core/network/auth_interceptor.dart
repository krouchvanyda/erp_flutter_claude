import 'package:dio/dio.dart';

import 'api_endpoints.dart';
import 'api_envelope.dart';
import 'auth_tokens.dart';
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
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Dio refreshDio,
    required void Function() onSessionExpired,
  }) : _tokenStorage = tokenStorage,
       _refreshDio = refreshDio,
       _onSessionExpired = onSessionExpired;

  final TokenStorage _tokenStorage;

  /// A SEPARATE Dio without this interceptor, for the refresh call and the
  /// retry — so they can never loop back into this interceptor.
  final Dio _refreshDio;

  /// Called when the session is really over (AuthSession.markLoggedOut).
  final void Function() _onSessionExpired;

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
      _onSessionExpired(); // no tokens at all → nothing to refresh
      return handler.next(err);
    }

    final AuthTokens fresh;
    if (request.headers[_header] != 'Bearer ${stored.accessToken}') {
      // Another queued request already refreshed while we waited.
      fresh = stored;
    } else {
      final result = await _refresh(stored.refreshToken);
      switch (result) {
        case RefreshOk(:final tokens):
          await _tokenStorage.write(tokens);
          fresh = tokens;
        case RefreshRejected():
          // Server says the refresh token is dead → the session is over.
          await _tokenStorage.clear();
          _onSessionExpired();
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
  Future<RefreshResult> _refresh(String refreshToken) async {
    try {
      final response = await _refreshDio.post<Object?>(
        ApiEndPoint.refresh,
        data: {'refreshToken': refreshToken},
      );
      final envelope = ApiEnvelope.tryParse(response.data);
      if (envelope != null && !envelope.success) return const RefreshRejected();
      final data = envelope?.data ?? response.data;
      return RefreshOk(AuthTokens.fromJson(data as Map<String, dynamic>));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // 400/401/403 = the server REFUSED the refresh token.
      if (status == 400 || status == 401 || status == 403) {
        return const RefreshRejected();
      }
      return const RefreshFailed(); // no answer: network, timeout, 5xx
    } catch (_) {
      return const RefreshFailed(); // unexpected body shape
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions request, AuthTokens tokens) {
    final options = request.copyWith(
      headers: {...request.headers, _header: 'Bearer ${tokens.accessToken}'},
      extra: {...request.extra, _retriedKey: true},
    );
    return _refreshDio.fetch<dynamic>(options);
  }
}

/// The 3 possible outcomes of a refresh call.
sealed class RefreshResult {
  const RefreshResult();
}

final class RefreshOk extends RefreshResult {
  const RefreshOk(this.tokens);
  final AuthTokens tokens;
}

/// The server said NO (refresh token expired / revoked) → log out.
final class RefreshRejected extends RefreshResult {
  const RefreshRejected();
}

/// We couldn't ask (offline, timeout, 5xx) → keep the session.
final class RefreshFailed extends RefreshResult {
  const RefreshFailed();
}
