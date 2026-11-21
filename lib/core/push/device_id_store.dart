import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// This install's id for the backend's device list (`deviceId`), Step 7.1.
///
/// Made ONCE (a random UUID) and kept in SharedPreferences: the same phone
/// keeps the same id across logins, so `POST /me/devices` updates its row
/// instead of adding a new one each time. Reinstalling the app → a new id.
/// Not a secret (it only names this install), so SharedPreferences is fine.
class DeviceIdStore {
  DeviceIdStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'push.device_id';

  String id() {
    final saved = _prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) return saved;
    final fresh = const Uuid().v4();
    _prefs.setString(_key, fresh); // not awaited: kept in memory meanwhile
    return fresh;
  }
}
