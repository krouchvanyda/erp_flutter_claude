import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/flavor.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_tokens.dart';
import '../../../core/network/dio_factory.dart';
import '../../../core/network/token_storage.dart';

/// Call requests from the BACKGROUND (Step 7.2): the push helper / the
/// notification's Decline, when the app (and its call bloc) may not be
/// running. Runs in a background isolate: `main()` didn't run, so there is
/// NO DI box, no session, no `AuthInterceptor`. It builds the little it needs.
///
/// - [ringing]: the ring notification is up → the caller sees "Ringing…"
///   (before, only the running app's bloc sent it → a KILLED app left the
///   caller on "Calling…").
/// - [reject]: Decline on the notification.
///
/// ```
/// read tokens ──► POST /calls/{id}/ringing|reject ──► 2xx ✓
///                        │ 401 (access token expired)
///                        ▼
///                 POST /auth/refresh ──► save the new pair ──► reject again
///                        │ refused / offline
///                        ▼
///                 give up (the caller hears "No answer" at 60 s)
/// ```
///
/// It NEVER clears the tokens or logs out: a refresh race with the running
/// app (rotated refresh token) must not log the user out from a background
/// tap. The worst case is a missed "declined", not a logout.
abstract final class BackgroundCallApi {
  /// "It's ringing on this phone" — the caller's screen: Calling… → Ringing…
  static Future<void> ringing(String callId) =>
      _post(ApiEndPoint.callRinging(callId), 'ringing');

  static Future<void> reject(String callId) =>
      _post(ApiEndPoint.callReject(callId), 'reject');

  static Future<void> _post(String path, String what) async {
    try {
      final storage = TokenStorage(TokenStorage.secureStorage);
      var tokens = await storage.read();
      if (tokens == null) return; // logged out
      // `Flavor.current` falls back to the --flavor build flag here (no pin).
      final dio = createDio(Flavor.current);

      Future<Response<Object?>> send(AuthTokens t) => dio.post<Object?>(
        path,
        options: Options(
          headers: {'Authorization': 'Bearer ${t.accessToken}'},
          validateStatus: (_) => true, // read the status ourselves
        ),
      );

      var response = await send(tokens);
      if (response.statusCode == 401) {
        final fresh = await _refresh(dio, tokens.refreshToken);
        if (fresh == null) return;
        await storage.write(fresh);
        tokens = fresh;
        response = await send(tokens);
      }
      debugPrint('[CallPush] background $what → ${response.statusCode}');
    } catch (e) {
      debugPrint('[CallPush] background $what failed: $e');
    }
  }

  static Future<AuthTokens?> _refresh(Dio dio, String refreshToken) async {
    try {
      final response = await dio.post<Object?>(
        ApiEndPoint.refresh,
        data: {'refreshToken': refreshToken},
      );
      final envelope = ApiEnvelope.tryParse(response.data);
      final data = envelope?.data ?? response.data;
      if (envelope != null && !envelope.success) return null;
      return AuthTokens.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null; // refused or offline → give up, keep the tokens
    }
  }
}
