import 'package:erp_mobile/core/network/auth_tokens.dart';
import 'package:erp_mobile/core/network/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TokenStorage storage;

  setUp(() {
    // In-memory fake of the Keychain / Keystore.
    FlutterSecureStorage.setMockInitialValues({});
    storage = TokenStorage(const FlutterSecureStorage());
  });

  final tokens = AuthTokens(
    accessToken: 'a1',
    refreshToken: 'r1',
    accessTokenExpiresAt: DateTime.utc(2026, 11, 19, 10),
  );

  test('empty at first', () async {
    expect(await storage.read(), isNull);
  });

  test('write then read gives the same pair', () async {
    await storage.write(tokens);
    expect(await storage.read(), tokens);
  });

  test('clear removes the pair', () async {
    await storage.write(tokens);
    await storage.clear();
    expect(await storage.read(), isNull);
  });

  test('a broken stored value is treated as "no session"', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_tokens': 'not json'});
    storage = TokenStorage(const FlutterSecureStorage());
    expect(await storage.read(), isNull);
  });

  test('toString never prints the real tokens', () {
    expect(tokens.toString(), isNot(contains('a1')));
  });
}
