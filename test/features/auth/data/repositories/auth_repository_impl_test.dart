import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:erp_mobile/core/database/app_database.dart';
import 'package:erp_mobile/core/error/logging_crash_reporter.dart';
import 'package:erp_mobile/core/network/auth_tokens.dart';
import 'package:erp_mobile/core/network/token_storage.dart';
import 'package:erp_mobile/core/utils/logger/log_level.dart';
import 'package:erp_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:erp_mobile/features/auth/data/datasources/cached_user_dao.dart';
import 'package:erp_mobile/features/auth/data/datasources/secure_token_storage.dart';
import 'package:erp_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:erp_mobile/features/auth/domain/entities/user.dart';
import 'package:test/test.dart';

import '../../../../_support/in_memory_secret_store.dart';
import '../../../../_support/recording_logger.dart';

class _RevokeCall {
  _RevokeCall(this.refreshToken);
  final String refreshToken;
}

/// Scriptable remote — tracks revoke calls and optionally throws.
class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  _FakeAuthRemoteDataSource({this.onRevoke});

  final Future<void> Function(String refreshToken)? onRevoke;
  final calls = <_RevokeCall>[];

  @override
  Future<void> revokeRefreshToken(String refreshToken) async {
    calls.add(_RevokeCall(refreshToken));
    if (onRevoke != null) await onRevoke!(refreshToken);
  }
}

DioException _dioErr(int status) => DioException(
      requestOptions: RequestOptions(path: '/auth/logout'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/auth/logout'),
        statusCode: status,
      ),
    );

({
  AuthRepositoryImpl repo,
  TokenStorage storage,
  _FakeAuthRemoteDataSource remote,
  CachedUserDao cache,
  AppDatabase db,
  RecordingLogger logger,
}) _build({
  Future<void> Function(String refreshToken)? onRevoke,
}) {
  final db = AppDatabase(NativeDatabase.memory());
  final secrets = InMemorySecretStore();
  final storage = SecureTokenStorage(secrets);
  final remote = _FakeAuthRemoteDataSource(onRevoke: onRevoke);
  final logger = RecordingLogger();
  final repo = AuthRepositoryImpl(
    tokenStorage: storage,
    remote: remote,
    cachedUserDao: db.cachedUserDao,
    logger: logger,
    crashReporter: LoggingCrashReporter(logger),
  );
  return (
    repo: repo,
    storage: storage,
    remote: remote,
    cache: db.cachedUserDao,
    db: db,
    logger: logger,
  );
}

Future<void> _seed(TokenStorage storage, CachedUserDao cache) async {
  await storage.write(const AuthTokens(
    accessToken: 'at',
    refreshToken: 'rt',
  ));
  await cache.cacheUser(const User(
    id: 'u-1',
    email: 'a@b.co',
    displayName: 'A',
    roles: {'admin'},
  ));
}

void main() {
  group('AuthRepositoryImpl.signOut — happy path', () {
    test('revokes the refresh token, then clears storage + drift', () async {
      final fx = _build();
      addTearDown(fx.db.close);
      await _seed(fx.storage, fx.cache);

      await fx.repo.signOut();

      // Server revoke fired with the stored refresh token.
      expect(fx.remote.calls, hasLength(1));
      expect(fx.remote.calls.single.refreshToken, 'rt');

      // Local cleanup complete.
      expect(await fx.storage.read(), isNull);
      expect(await fx.cache.getCurrentUser(), isNull);
      expect(await fx.cache.getPermissions('u-1'), isEmpty);
    });

    test('logs server-side revoke success', () async {
      final fx = _build();
      addTearDown(fx.db.close);
      await _seed(fx.storage, fx.cache);

      await fx.repo.signOut();

      final infos = fx.logger.at(LogLevel.info).toList();
      expect(
        infos.any((r) => r.message.contains('revoke succeeded')),
        isTrue,
      );
      expect(
        infos.any((r) => r.message.contains('local sign-out completed')),
        isTrue,
      );
    });
  });

  group('AuthRepositoryImpl.signOut — no stored tokens', () {
    test('skips server revoke but still wipes local state', () async {
      final fx = _build();
      addTearDown(fx.db.close);
      // Drift cache present but secure-storage empty (split-brain or
      // boot-time defensive cleanup).
      await fx.cache.cacheUser(const User(
        id: 'u-1',
        email: 'a@b.co',
        displayName: 'A',
      ));

      await fx.repo.signOut();

      expect(fx.remote.calls, isEmpty, reason: 'no token → no revoke call');
      expect(await fx.cache.getCurrentUser(), isNull);

      final infos = fx.logger.at(LogLevel.info).toList();
      expect(
        infos.any((r) => r.message.contains('no tokens to revoke')),
        isTrue,
      );
    });
  });

  group('AuthRepositoryImpl.signOut — server failure', () {
    test('DioException from revoke is logged at warning + cleanup proceeds',
        () async {
      final fx = _build(onRevoke: (_) async {
        throw _dioErr(503);
      });
      addTearDown(fx.db.close);
      await _seed(fx.storage, fx.cache);

      // Must NOT throw — local sign-out succeeds regardless.
      await fx.repo.signOut();

      expect(fx.remote.calls, hasLength(1));
      expect(await fx.storage.read(), isNull);
      expect(await fx.cache.getCurrentUser(), isNull);

      final warnings = fx.logger.at(LogLevel.warning).toList();
      expect(warnings, hasLength(1));
      expect(warnings.single.message, contains('auth.revoke failed'));
    });

    test('non-Dio exception from revoke is also swallowed', () async {
      final fx = _build(onRevoke: (_) async {
        throw StateError('something else broke');
      });
      addTearDown(fx.db.close);
      await _seed(fx.storage, fx.cache);

      await fx.repo.signOut(); // should not throw

      expect(await fx.storage.read(), isNull);
      expect(await fx.cache.getCurrentUser(), isNull);
    });
  });
}
