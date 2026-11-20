import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The logged-in user (the login response's `user`), kept on the phone.
///
/// ```
/// login   ──► save(user JSON)  ──► shared_preferences
/// profile ──► read()           ──► UserModel.fromJson(...)
/// logout / session over ──► clear()
/// ```
///
/// - It stores the server's RAW JSON map. `core/` can't import
///   `UserModel` (that's in `features/auth`), and we don't need a `toJson`:
///   the server already gave us JSON.
/// - Not a secret (name, email, phone, avatar path), so `shared_preferences`
///   is fine. Tokens NEVER go here (they live in `TokenStorage`).
/// - It must be cleared on logout and when the session ends, so the next
///   person on this phone never sees the old user.
class UserCache {
  UserCache(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'cached_user';

  /// null = nothing saved (never logged in, or logged in before the cache
  /// existed). Sync: SharedPreferences keeps its values in memory.
  Map<String, dynamic>? read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _prefs.remove(_key); // broken value → as if nothing was saved
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> userJson) =>
      _prefs.setString(_key, jsonEncode(userJson));

  Future<void> clear() => _prefs.remove(_key);
}
