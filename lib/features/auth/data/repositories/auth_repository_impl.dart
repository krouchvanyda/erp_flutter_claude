import '../../../../core/error/crash_reporter.dart';
import '../../../../core/network/token_storage.dart';
import '../../../../core/utils/logger/app_logger.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/cached_user_dao.dart';

/// Concrete [AuthRepository] for the data layer.
///
/// **Sign-out ordering** is deliberate:
///   1. **Revoke first** — while tokens are still valid, ask the server to
///      invalidate the refresh chain so a stolen refresh token can't be
///      reused after the user has signed out from this device.
///   2. **Local cleanup second** — clear secure storage *and* drift (the
///      user profile + permissions cache).
///   3. **Server failures don't block local cleanup** — if the revoke
///      throws, log + crash-report at `warning`, then continue with the
///      wipe. A user trying to sign out while offline must still succeed
///      locally; the server's stale refresh chain ages out on its own.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required TokenStorage tokenStorage,
    required AuthRemoteDataSource remote,
    required CachedUserDao cachedUserDao,
    required AppLogger logger,
    required CrashReporter crashReporter,
  })  : _tokenStorage = tokenStorage,
        _remote = remote,
        _cache = cachedUserDao,
        _logger = logger.child('auth.repository'),
        _crash = crashReporter;

  final TokenStorage _tokenStorage;
  final AuthRemoteDataSource _remote;
  final CachedUserDao _cache;
  final AppLogger _logger;
  final CrashReporter _crash;

  @override
  Future<void> signOut() async {
    final tokens = await _tokenStorage.read();

    // Step 1 — best-effort server revoke. Skipped when we have no
    // refresh token (e.g. logout button hit twice / boot-time cleanup).
    if (tokens != null) {
      try {
        await _remote.revokeRefreshToken(tokens.refreshToken);
        _logger.info('server-side refresh-token revoke succeeded');
      } catch (e, stack) {
        _crash.report(
          e,
          stack,
          severity: CrashSeverity.warning,
          description: 'auth.revoke failed; continuing local sign-out',
        );
      }
    } else {
      _logger.info('no tokens to revoke — local cleanup only');
    }

    // Step 2 — local cleanup. These two must both run even if one
    // throws, so the user isn't half-signed-out. Each call is itself
    // safe to retry on app restart, but a partial state (storage cleared,
    // drift not, or vice-versa) would confuse the splash probe.
    Object? localError;
    StackTrace? localStack;
    try {
      await _tokenStorage.clear();
    } catch (e, stack) {
      localError = e;
      localStack = stack;
    }
    try {
      await _cache.wipeAll();
    } catch (e, stack) {
      localError ??= e;
      localStack ??= stack;
    }

    if (localError != null) {
      _crash.report(
        localError,
        localStack,
        severity: CrashSeverity.error,
        description: 'auth.signOut local cleanup partially failed',
      );
      // Bubble up so the use case can decide whether to retry on next
      // boot; the user is still being signed out either way.
      Error.throwWithStackTrace(localError, localStack ?? StackTrace.current);
    }

    _logger.info('local sign-out completed');
  }
}
