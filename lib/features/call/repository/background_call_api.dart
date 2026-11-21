import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/flavor.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_tokens.dart';
import '../../../core/network/dio_factory.dart';
import '../../../core/network/token_storage.dart';

/// "Decline" from the ring notification when the app is NOT running
/// (Step 7.2). Runs in a background isolate: `main()` didn't run, so there is
/// NO DI box, no session, no `AuthInterceptor`. It builds the little it needs.
///
/// ```
/// read tokens ──► POST /calls/{id}/reject ──► 2xx ✓
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
  static Future<void> reject(String callId) async {
    try {
      final storage = TokenStorage(TokenStorage.secureStorage);
      var tokens = await storage.read();
      if (tokens == null) return; // logged out
      // `Flavor.current` falls back to the --flavor build flag here (no pin).
      final dio = createDio(Flavor.current);

      Future<Response<Object?>> send(AuthTokens t) => dio.post<Object?>(
        ApiEndPoint.callReject(callId),
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
      debugPrint('[CallPush] background reject → ${response.statusCode}');
    } catch (e) {
      debugPrint('[CallPush] background reject failed: $e');
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
