import '../di/injection.dart';
import 'connectivity_checker.dart';

/// "Is the device online?" (template: `CheckInternetService`).
///
/// Uses the app's `connectivity_plus`-backed [ConnectivityChecker] instead of
/// pinging google.com — the backend is on the office LAN, which may have no
/// public internet while the API is perfectly reachable.
class CheckInternetService {
  CheckInternetService._();

  static Future<bool> checkDataConnection() async {
    if (!getIt.isRegistered<ConnectivityChecker>()) return true;
    try {
      return await getIt<ConnectivityChecker>().isOnline;
    } catch (_) {
      // Never block a request just because the check itself failed.
      return true;
    }
  }
}
