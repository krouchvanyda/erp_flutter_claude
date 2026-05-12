import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:erp_mobile/core/di/app_env.dart';
import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/core/network/auth_tokens.dart';
import 'package:erp_mobile/features/auth/data/datasources/oauth_flow_session.dart';
import 'package:erp_mobile/features/auth/data/datasources/oauth_token_data_source.dart';
import 'package:erp_mobile/features/auth/domain/entities/pkce_challenge.dart';
import 'package:erp_mobile/features/auth/domain/usecases/exchange_authorization_code.dart';
import 'package:test/test.dart';

import '../../../../_support/in_memory_secret_store.dart';
import 'package:erp_mobile/features/auth/data/datasources/secure_token_storage.dart';

const _challenge = PkceChallenge(
  verifier: 'verifier-test-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  challenge: 'challenge-test',
);

const _env = AppEnv(
  apiBaseUrl: 'https://example.test',
  connectTimeoutMs: 1000,
  receiveTimeoutMs: 1000,
  enableNetworkLogging: false,
  oauthClientId: 'erp-mobile-dev',
  oauthRedirectUri: 'erpmobile://oauth/callback',
);

class _ExchangeCall {
  _ExchangeCall({
    required this.code,
    required this.codeVerifier,
    required this.redirectUri,
    required this.clientId,
  });
  final String code;
  final String codeVerifier;
  final String redirectUri;
  final String clientId;
}

/// Scriptable token data source — tracks call args and lets the test
/// pin the response (or throw).
class _FakeTokenDataSource implements OAuthTokenDataSource {
  _FakeTokenDataSource({this.respond});
  final Future<AuthTokens> Function(_ExchangeCall call)? respond;
  final calls = <_ExchangeCall>[];

  @override
  Future<AuthTokens> exchangeAuthorizationCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
    required String clientId,
  }) {
    final c = _ExchangeCall(
      code: code,
      codeVerifier: codeVerifier,
      redirectUri: redirectUri,
      clientId: clientId,
    );
    calls.add(c);
    return respond?.call(c) ??
        Future.value(const AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
        ));
  }
}

DioException _dioErr(int status) => DioException(
      requestOptions: RequestOptions(path: '/oauth/token'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/oauth/token'),
        statusCode: status,
      ),
    );

({
  ExchangeAuthorizationCodeUseCase useCase,
  OAuthFlowSession session,
  _FakeTokenDataSource ds,
  SecureTokenStorage storage,
  InMemorySecretStore secrets,
}) _build({
  Future<AuthTokens> Function(_ExchangeCall call)? respond,
}) {
  final session = OAuthFlowSession();
  final ds = _FakeTokenDataSource(respond: respond);
  final secrets = InMemorySecretStore();
  final storage = SecureTokenStorage(secrets);
  final useCase = ExchangeAuthorizationCodeUseCase(
    session: session,
    dataSource: ds,
    tokenStorage: storage,
    env: _env,
  );
  return (
    useCase: useCase,
    session: session,
    ds: ds,
    storage: storage,
    secrets: secrets,
  );
}

void main() {
  group('ExchangeAuthorizationCodeUseCase — happy path', () {
    test('consumes verifier, exchanges code, persists tokens', () async {
      final fx = _build();
      fx.session.begin(challenge: _challenge, state: 'csrf-1');

      final result = await fx.useCase.call(
        authorizationCode: 'authcode-xyz',
        state: 'csrf-1',
      );

      expect(result.isRight(), isTrue);
      expect(result.getOrElse(() => fail('expected ok')), unit);

      // Data source called with the right args.
      expect(fx.ds.calls, hasLength(1));
      final call = fx.ds.calls.single;
      expect(call.code, 'authcode-xyz');
      expect(call.codeVerifier, _challenge.verifier);
      expect(call.redirectUri, _env.oauthRedirectUri);
      expect(call.clientId, _env.oauthClientId);

      // Tokens landed in secure storage.
      final stored = await fx.storage.read();
      expect(stored, isNotNull);
      expect(stored!.accessToken, 'a');
      expect(stored.refreshToken, 'r');

      // Session was wiped.
      expect(fx.session.hasActiveFlow, isFalse);
    });
  });

  group('ExchangeAuthorizationCodeUseCase — CSRF mismatch', () {
    test('returns UnauthorizedFailure and never calls the data source',
        () async {
      final fx = _build();
      fx.session.begin(challenge: _challenge, state: 'real-nonce');

      final result = await fx.useCase.call(
        authorizationCode: 'c',
        state: 'forged-nonce',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<UnauthorizedFailure>()),
        (_) => fail('expected error'),
      );
      expect(fx.ds.calls, isEmpty,
          reason: 'must not exchange when state mismatched');
      expect(await fx.storage.read(), isNull,
          reason: 'no tokens ever written');

      // Session is wiped even on mismatch (by OAuthFlowSession contract).
      expect(fx.session.hasActiveFlow, isFalse);
    });

    test('no in-flight flow at all returns UnauthorizedFailure', () async {
      final fx = _build();
      // No session.begin() — straight to the callback.

      final result = await fx.useCase.call(
        authorizationCode: 'c',
        state: 'whatever',
      );

      result.fold(
        (failure) => expect(failure, isA<UnauthorizedFailure>()),
        (_) => fail('expected error'),
      );
      expect(fx.ds.calls, isEmpty);
    });
  });

  group('ExchangeAuthorizationCodeUseCase — server failures', () {
    test('DioException maps through failureFromDioException, no tokens written',
        () async {
      final fx = _build(respond: (_) async => throw _dioErr(503));
      fx.session.begin(challenge: _challenge, state: 's');

      final result = await fx.useCase.call(
        authorizationCode: 'c',
        state: 's',
      );

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected error'),
      );
      expect(await fx.storage.read(), isNull);

      // Session was already wiped by consumeVerifier.
      expect(fx.session.hasActiveFlow, isFalse);
    });

    test('FormatException from token parsing → UnknownFailure', () async {
      final fx = _build(
        respond: (_) async =>
            throw const FormatException('missing access_token'),
      );
      fx.session.begin(challenge: _challenge, state: 's');

      final result = await fx.useCase.call(
        authorizationCode: 'c',
        state: 's',
      );

      result.fold(
        (failure) {
          expect(failure, isA<UnknownFailure>());
          expect((failure as UnknownFailure).message,
              'missing access_token');
        },
        (_) => fail('expected error'),
      );
      expect(await fx.storage.read(), isNull);
    });
  });

  group('ExchangeAuthorizationCodeUseCase — storage rule (1.2.2)', () {
    test('verifier never reaches the secret store directly', () async {
      final fx = _build();
      fx.session.begin(challenge: _challenge, state: 'csrf-1');
      await fx.useCase.call(
        authorizationCode: 'authcode',
        state: 'csrf-1',
      );

      // The only key written is the SecureTokenStorage blob — `auth.tokens.v1`.
      expect(fx.secrets.writes, ['auth.tokens.v1']);
      // The verifier text is not in the stored payload.
      final stored = fx.secrets.peek('auth.tokens.v1')!;
      expect(stored.contains(_challenge.verifier), isFalse,
          reason: 'verifier must never reach secure storage');
    });
  });
}
