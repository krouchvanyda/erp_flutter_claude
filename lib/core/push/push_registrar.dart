import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/api_endpoints.dart';
import '../network/app_service.dart';
import '../network/helper_service.dart';
import '../router/auth_session.dart';
import 'device_id_store.dart';
import 'push_messaging.dart';

/// Tells OUR backend where to push for the logged-in user (Step 7.1).
///
/// ```
/// logged in (login / auto-login) ──► ask permission ──► token ──► POST /me/devices
/// token refreshed (while logged in) ───────────────────────────► POST /me/devices
/// logout (BEFORE the tokens are cleared) ──────────────────────► DELETE /me/devices/{id}
/// ```
///
/// Why DELETE on logout matters: the backend keys devices by (user,
/// deviceId). If A logs out without it and B logs in on the same phone, A's
/// row still points at this phone → A's calls would ring B. Best effort
/// (offline → we still log out), so the backend should also drop the token
/// from other users when B registers it (noted for the backend team).
class PushRegistrar {
  PushRegistrar({
    required AppService appService,
    required AuthSession session,
    required DeviceIdStore deviceIds,
    required PushMessaging messaging,
    required String platform,
  }) : _appService = appService,
       _session = session,
       _deviceIds = deviceIds,
       _messaging = messaging,
       _platform = platform;

  final AppService _appService;
  final AuthSession _session;
  final DeviceIdStore _deviceIds;
  final PushMessaging _messaging;

  /// `android` / `ios` (the backend's `DevicePlatform`).
  final String _platform;

  StreamSubscription<String>? _refresh;

  /// The token the server already has (this login). Same token again → skip.
  String? _sentToken;

  /// The POST running now, and its token: a second caller with the SAME
  /// token waits for it instead of sending a twin. At start-up iOS fires
  /// `onTokenRefresh` at the same moment as the login hook, and two
  /// parallel POSTs both "insert" on the server → duplicate key → 500.
  Future<void>? _inFlight;
  String? _inFlightToken;

  /// How long logout waits for the DELETE before going on.
  static const Duration unregisterTimeout = Duration(seconds: 3);

  /// Start following the session. Call once at start-up.
  void attach() {
    _session.addListener(_onSession);
    _refresh = _messaging.onTokenRefresh.listen((token) {
      if (_session.isAuthenticated) _register(token);
    });
    _onSession(); // already logged in (attach after the splash)?
  }

  void detach() {
    _session.removeListener(_onSession);
    _refresh?.cancel();
  }

  void _onSession() {
    if (_session.isAuthenticated) {
      unawaited(register());
    } else {
      _sentToken = null; // next login → send again (maybe another user)
    }
  }

  /// Ask for the permission, get the token, save it on the server.
  /// Never throws; a failure just means no push for now.
  Future<void> register() async {
    await _messaging.requestPermission();
    final token = await _messaging.token();
    if (token == null || !_session.isAuthenticated) return;
    await _register(token);
  }

  Future<void> _register(String token) {
    if (token == _sentToken) return Future.value();
    final running = _inFlight;
    if (running != null && _inFlightToken == token) return running;
    final sending = _send(token);
    _inFlight = sending;
    _inFlightToken = token;
    return sending.whenComplete(() {
      if (identical(_inFlight, sending)) {
        _inFlight = null;
        _inFlightToken = null;
      }
    });
  }

  Future<void> _send(String token) async {
    final result = await _appService.send<void>(
      httpMethods: HttpMethods.post,
      endPoint: ApiEndPoint.myDevices,
      data: {
        'deviceId': _deviceIds.id(),
        'fcmToken': token,
        'platform': _platform,
      },
      parse: (_) {},
    );
    result.fold(
      (error) => debugPrint('[Push] register failed: ${error.description}'),
      (_) => _sentToken = token,
    );
  }

  /// Logout: this phone stops getting the user's pushes. MUST run while the
  /// access token is still stored (the request needs it). Best effort.
  Future<void> unregister() async {
    _sentToken = null;
    try {
      await _appService
          .send<void>(
            httpMethods: HttpMethods.delete,
            endPoint: ApiEndPoint.myDevice(_deviceIds.id()),
            parse: (_) {},
          )
          .timeout(unregisterTimeout);
    } catch (_) {
      // timeout: the user still logs out (the backend note above covers it)
    }
  }
}
