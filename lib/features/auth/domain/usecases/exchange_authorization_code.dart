import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/di/app_env.dart';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_from_dio.dart';
import '../../../../core/network/token_storage.dart';
import '../../data/datasources/oauth_flow_session.dart';
import '../../data/datasources/oauth_token_data_source.dart';

/// "OAuth callback received → trade the code for tokens".
///
/// **Storage rule**: the verifier comes out of the in-memory
/// [OAuthFlowSession] and is consumed (cleared) on every call regardless
/// of outcome. The resulting [AuthTokens] are written to the secure
/// [TokenStorage] — never to drift, `shared_preferences`, or anywhere
/// else. CLAUDE.md Slice 1.2.2: *"verifier/challenge in memory,
/// resulting tokens → flutter_secure_storage"*.
///
/// Failure modes mapped to typed [Failure]s:
/// - **CSRF mismatch / no flow in progress** → [UnauthorizedFailure].
/// - **Transport / 4xx / 5xx** → propagated through `failureFromDioException`.
/// - **Malformed token response** → [UnknownFailure] (the body parser
///   throws `FormatException`).
class ExchangeAuthorizationCodeUseCase {
  const ExchangeAuthorizationCodeUseCase({
    required OAuthFlowSession session,
    required OAuthTokenDataSource dataSource,
    required TokenStorage tokenStorage,
    required AppEnv env,
  })  : _session = session,
        _dataSource = dataSource,
        _tokenStorage = tokenStorage,
        _env = env;

  final OAuthFlowSession _session;
  final OAuthTokenDataSource _dataSource;
  final TokenStorage _tokenStorage;
  final AppEnv _env;

  Future<Result<Unit>> call({
    required String authorizationCode,
    required String state,
  }) async {
    // Pop the verifier — wipes the session even on mismatch, so a
    // failed attempt can't be replayed with a stolen state nonce.
    final verifier = _session.consumeVerifier(state: state);
    if (verifier == null) {
      return err(
        const Failure.unauthorized(
          message: 'OAuth state mismatch or no flow in progress',
        ),
      );
    }

    try {
      final tokens = await _dataSource.exchangeAuthorizationCode(
        code: authorizationCode,
        codeVerifier: verifier,
        redirectUri: _env.oauthRedirectUri,
        clientId: _env.oauthClientId,
      );
      // Persist into secure storage — the auth interceptor and
      // refresher will pick up the new tokens automatically on the
      // next outbound call.
      await _tokenStorage.write(tokens);
      return ok(unit);
    } on DioException catch (e) {
      return err(failureFromDioException(e));
    } on FormatException catch (e) {
      return err(Failure.unknown(message: e.message));
    }
  }
}
