package com.enterprise.erp.erp_callkit

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

/**
 * Minimal native HTTP client used ONLY by the killed-app Reject path.
 * Plain `HttpURLConnection` (no extra deps). Mirrors the Dart REST
 * contract:
 *   - reject:  POST {base}/chats/calls/{id}/reject?reason=declined   (Bearer)
 *   - refresh: POST {base}/auth/refresh   body {"refresh_token": ...}
 *              → {access_token, refresh_token, expires_at}
 *
 * On a 401 (access token expired while the app was killed) we refresh
 * once using the stored refresh token, persist the rotated pair back to
 * secure storage, and retry the reject.
 */
object BackendCallClient {
    private const val TAG = "ErpCallHttp"
    private const val TIMEOUT_MS = 10_000

    fun rejectCall(
        context: Context,
        baseUrl: String,
        callId: String,
        reason: String,
        bundleAccessToken: String = "",
        bundleRefreshToken: String = "",
    ): Boolean {
        // Prefer the Dart-supplied tokens — they're read in Dart where
        // flutter_secure_storage works reliably. Fall back to the native
        // SecureTokenReader only for whichever token the bundle didn't
        // carry (legacy callers / pre-fix notifications still in the tray).
        // The native read can throw AEADBadTagException on some OEMs, which
        // is exactly the bug this path now routes around.
        var access = bundleAccessToken
        var refreshToken = bundleRefreshToken
        if (access.isEmpty() || refreshToken.isEmpty()) {
            val tokens = SecureTokenReader.read(context)
            if (tokens != null) {
                if (access.isEmpty()) access = tokens.access
                if (refreshToken.isEmpty()) refreshToken = tokens.refresh
            }
        }
        if (access.isEmpty()) {
            Log.w(TAG, "no access token (bundle empty + SecureTokenReader failed) — cannot authenticate reject")
            return false
        }

        var code = postReject(baseUrl, callId, reason, access)
        if (code == HttpURLConnection.HTTP_UNAUTHORIZED && refreshToken.isNotEmpty()) {
            Log.i(TAG, "reject got 401 — refreshing access token")
            val newAccess = refresh(context, baseUrl, refreshToken)
            if (newAccess != null) {
                code = postReject(baseUrl, callId, reason, newAccess)
            }
        }
        Log.i(TAG, "reject final HTTP code=$code (callId=$callId)")
        return code in 200..299
    }

    private fun postReject(baseUrl: String, callId: String, reason: String, access: String): Int {
        val url = URL("${trimBase(baseUrl)}/chats/calls/$callId/reject?reason=$reason")
        val conn = url.openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = "POST"
            conn.connectTimeout = TIMEOUT_MS
            conn.readTimeout = TIMEOUT_MS
            conn.setRequestProperty("Authorization", "Bearer $access")
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Accept", "application/json")
            conn.doOutput = false
            conn.connect()
            val c = conn.responseCode
            Log.i(TAG, "POST /chats/calls/$callId/reject → $c")
            c
        } catch (e: Exception) {
            Log.e(TAG, "postReject error: ${e.message}", e)
            -1
        } finally {
            try { conn.disconnect() } catch (_: Exception) {}
        }
    }

    private fun refresh(context: Context, baseUrl: String, refreshToken: String): String? {
        val url = URL("${trimBase(baseUrl)}/auth/refresh")
        val conn = url.openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = "POST"
            conn.connectTimeout = TIMEOUT_MS
            conn.readTimeout = TIMEOUT_MS
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Accept", "application/json")
            conn.doOutput = true
            val body = JSONObject().put("refresh_token", refreshToken).toString()
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }

            val code = conn.responseCode
            if (code !in 200..299) {
                Log.w(TAG, "refresh failed code=$code")
                return null
            }
            val resp = BufferedReader(InputStreamReader(conn.inputStream, Charsets.UTF_8))
                .use { it.readText() }
            val json = JSONObject(resp)
            val access = json.optString("access_token", "")
            val newRefresh = json.optString("refresh_token", "")
            val expires = if (json.has("expires_at")) json.optString("expires_at", "") else ""
            if (access.isEmpty() || newRefresh.isEmpty()) {
                Log.w(TAG, "refresh response missing access/refresh token")
                return null
            }
            SecureTokenReader.writeRefreshed(
                context, access, newRefresh, expires.ifEmpty { null }
            )
            access
        } catch (e: Exception) {
            Log.e(TAG, "refresh error: ${e.message}", e)
            null
        } finally {
            try { conn.disconnect() } catch (_: Exception) {}
        }
    }

    private fun trimBase(s: String): String = if (s.endsWith("/")) s.dropLast(1) else s
}
