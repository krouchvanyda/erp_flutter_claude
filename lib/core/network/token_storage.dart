import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_tokens.dart';

/// Saves the token pair in the phone's secure vault:
/// iOS Keychain / Android Keystore (encrypted). NEVER SharedPreferences.
///
/// Tokens survive app kills (that's what makes auto-login work in Step 3).
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  /// One key, one JSON value → the pair is always written together.
  static const String _key = 'auth_tokens';

  /// Options for the real app (passed in DI):
  /// - Android: encrypted shared preferences (Keystore-backed).
  /// - iOS: readable after the FIRST unlock since boot — so the background
  ///   isolate that rings a killed app (Step 7) can still read the token
  ///   while the phone is locked in a pocket.
  static const FlutterSecureStorage secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<AuthTokens?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return AuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear(); // broken value → treat as "no session"
      return null;
    }
  }

  Future<void> write(AuthTokens tokens) =>
      _storage.write(key: _key, value: jsonEncode(tokens.toJson()));

  /// Logout / refresh failed. Skipping this would re-enable auto-login —
  /// a security bug (CLAUDE.md).
  Future<void> clear() => _storage.delete(key: _key);
}
