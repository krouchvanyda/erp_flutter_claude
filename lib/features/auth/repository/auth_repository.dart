import 'package:dartz/dartz.dart' show Either, Left, Right;

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/app_service.dart';
import '../../../core/network/helper_service.dart';
import '../../../core/network/network_error_model.dart';
import '../../../core/network/token_storage.dart';
import '../../../core/router/auth_session.dart';
import '../../../core/storage/user_cache.dart';
import '../model/auth_response_model.dart';
import '../model/user_model.dart';

/// Auth business rules. The BLoC calls this; it never touches Dio or tokens.
///
/// login = ask the server → SAVE the tokens (+ the user) → OPEN the session.
/// The order matters: tokens are saved BEFORE the session opens, so the very
/// first request after login already carries the token.
class AuthRepository {
  AuthRepository({
    required AppService appService,
    required TokenStorage tokenStorage,
    required UserCache userCache,
    required AuthSession session,
    Future<void> Function()? beforeLogout,
  }) : _appService = appService,
       _beforeLogout = beforeLogout,
       _tokenStorage = tokenStorage,
       _userCache = userCache,
       _session = session;

  final AppService _appService;
  final TokenStorage _tokenStorage;
  final UserCache _userCache;
  final AuthSession _session;

  /// Runs at the START of [logout], while the tokens are still stored
  /// (Step 7.1: `PushRegistrar.unregister`). Given by DI.
  final Future<void> Function()? _beforeLogout;

  Future<Either<NetworkErrorModel, UserModel>> login({
    required String email,
    required String password,
  }) async {
    final result = await _appService.send(
      httpMethods: HttpMethods.post,
      endPoint: ApiEndPoint.login,
      data: {'email': email.trim(), 'password': password},
      // The model AND the raw `user` map (UserCache saves the server's JSON
      // as-is, so UserModel needs no toJson).
      parse: (data) => (
        AuthResponseModel.fromData(data),
        (data as Map<String, dynamic>)['user'] as Map<String, dynamic>,
      ),
    );

    // fold = handle both boxes. The success side is async (we save tokens),
    // so both sides return a Future.
    return result.fold<Future<Either<NetworkErrorModel, UserModel>>>(
      (error) async => Left(error), // wrong password, offline… → pass it up
      (parsed) async {
        final (response, userJson) = parsed;
        await _tokenStorage.write(response.tokens); // 1. save tokens
        await _userCache.save(userJson); //            2. remember the user
        _session.markAuthenticated(); //               3. open the session
        return Right(response.user);
      },
    );
  }

  /// Splash (auto-login): "is there a saved session?" — NO network call.
  ///
  /// - no tokens                → false (show Login)
  /// - refresh token expired    → clear tokens, false (it can never work)
  /// - otherwise                → OPEN the session, true (show Home)
  ///
  /// The ACCESS token is not checked: an expired one is fine, the first
  /// request refreshes it in the AuthInterceptor (CLAUDE.md).
  Future<bool> restoreSession() async {
    final tokens = await _tokenStorage.read();
    if (tokens == null) return false;

    final refreshExpiresAt = tokens.refreshTokenExpiresAt;
    if (refreshExpiresAt != null && refreshExpiresAt.isBefore(DateTime.now())) {
      await _tokenStorage.clear(); // dead tokens → don't keep them
      await _userCache.clear();
      return false;
    }

    _session.markAuthenticated();
    return true;
  }

  /// Logout = tell the server → CLEAR the tokens → CLOSE the session.
  ///
  /// 1. Server first: `POST /auth/logout` needs the access token, and the
  ///    interceptor reads it from storage — so we can't clear before.
  /// 2. "Best effort": offline, timeout or 500 → we still log out locally.
  ///    The user pressed "Log out"; they must never stay logged in.
  /// 3. `finally` → the clear + close ALWAYS run (CLAUDE.md: skipping
  ///    `TokenStorage.clear()` re-enables auto-login = security bug).
  Future<void> logout() async {
    try {
      // e.g. stop this phone's pushes (Step 7.1). Needs the access token,
      // so it runs FIRST; a failure never stops the logout.
      try {
        await _beforeLogout?.call();
      } catch (_) {}
      final tokens = await _tokenStorage.read();
      if (tokens != null) {
        await _appService
            .send<void>(
              httpMethods: HttpMethods.post,
              endPoint: ApiEndPoint.logout,
              data: {'refreshToken': tokens.refreshToken},
              parse: (_) {}, // nothing to read back
            )
            // Don't make the user wait 15 s for a dead server.
            .timeout(
              logoutTimeout,
              onTimeout: () => const Left(UnknownError()),
            );
      }
    } finally {
      await _tokenStorage.clear(); // 1. no more auto-login
      await _userCache.clear(); //    2. forget who was logged in
      _session.markLoggedOut(); //    3. AuthGate → Login
    }
  }

  /// How long logout waits for the server before giving up.
  static const Duration logoutTimeout = Duration(seconds: 5);
}
