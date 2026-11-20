import 'package:dio/dio.dart';

import 'api_endpoints.dart';
import 'api_envelope.dart';
import 'auth_tokens.dart';
import 'token_storage.dart';

/// The ONE place that refreshes the token pair (Step 5.3).
///
/// Two callers need it:
/// - `AuthInterceptor`: a REST request got 401.
/// - `RealtimeService`: the socket wants a fresh token BEFORE it connects.
///
/// ```
/// refresh() ──► already running? ──yes──► wait for THAT one (same result)
///                      │ no
///                      ▼
///          POST /auth/refresh ──► Ok       → save the new pair
///                                ├► Rejected → clear tokens + session over
///                                └► Failed   → keep tokens (offline / 5xx)
/// ```
///
/// **Single flight is a must.** The refresh token is ROTATED: each use gives
/// a new one and kills the old one. If the socket and a REST call refreshed at
/// the same time, the second would send a dead token → "Rejected" → the user
/// is logged out for no reason.
class TokenRefresher {
  TokenRefresher({
    required TokenStorage tokenStorage,
    required Dio refreshDio,
    required void Function() onSessionExpired,
  }) : _tokenStorage = tokenStorage,
       _refreshDio = refreshDio,
       _onSessionExpired = onSessionExpired;

  final TokenStorage _tokenStorage;

  /// A Dio WITHOUT the auth interceptor → a refresh can never loop.
  final Dio _refreshDio;
  final void Function() _onSessionExpired;

  Future<RefreshResult>? _inFlight;

  /// Refresh with the refresh token that is stored NOW. Callers that come
  /// while one is running get the SAME future.
  Future<RefreshResult> refresh() =>
      _inFlight ??= _run().whenComplete(() => _inFlight = null);

  /// Tokens whose access token is valid for at least [margin], refreshing
  /// first if needed. null = no session, or the refresh failed / was refused.
  /// (Tokens without an expiry time are used as they are.)
  Future<AuthTokens?> validTokens({
    Duration margin = const Duration(seconds: 60),
  }) async {
    final tokens = await _tokenStorage.read();
    if (tokens == null) return null;
    final expiresAt = tokens.accessTokenExpiresAt;
    if (expiresAt == null || expiresAt.isAfter(DateTime.now().add(margin))) {
      return tokens;
    }
    return switch (await refresh()) {
      RefreshOk(:final tokens) => tokens,
      _ => null,
    };
  }

  /// The session is over (no tokens, or the server refused them).
  Future<void> expireSession() async {
    await _tokenStorage.clear();
    _onSessionExpired();
  }

  Future<RefreshResult> _run() async {
    final stored = await _tokenStorage.read();
    if (stored == null) {
      _onSessionExpired(); // nothing to refresh with
      return const RefreshRejected();
    }
    final result = await _call(stored.refreshToken);
    switch (result) {
      case RefreshOk(:final tokens):
        await _tokenStorage.write(tokens);
      case RefreshRejected():
        await expireSession(); // dead refresh token → log out
      case RefreshFailed():
        break; // not the user's fault → keep the session
    }
    return result;
  }

  Future<RefreshResult> _call(String refreshToken) async {
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
