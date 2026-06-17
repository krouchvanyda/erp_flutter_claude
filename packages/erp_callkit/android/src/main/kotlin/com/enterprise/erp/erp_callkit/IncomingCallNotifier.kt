package com.enterprise.erp.erp_callkit

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat
import java.net.HttpURLConnection
import java.net.URL

/**
 * Builds and tears down the native incoming-call notification.
 *
 * The whole reason this is native: the **Reject** action's
 * [PendingIntent] targets [CallActionReceiver] explicitly, so tapping
 * Reject runs Kotlin even when the app process is dead. The notification
 * also carries a full-screen intent (→ MainActivity) so a locked device
 * shows the in-app incoming-call UI, plus an Accept action that launches
 * the app to join.
 */
object IncomingCallNotifier {
    private const val TAG = "ErpCallNotifier"

    const val CHANNEL_ID = "erp_incoming_calls"
    const val EXTRA_CALL_DATA = "erp_call_data"
    const val ACTION_REJECT = "com.enterprise.erp.erp_callkit.ACTION_REJECT"
    const val ACTION_TIMEOUT = "com.enterprise.erp.erp_callkit.ACTION_TIMEOUT"
    const val EXTRA_NOTIF_ID = "erp_notif_id"

    /**
     * Hard ceiling on how long the incoming-call heads-up may stay on
     * screen with no user action and no cancel signal. Mirrors the 60 s
     * ring timeout in `CallSignalingService` so a missed / orphaned ring
     * self-clears instead of lingering forever. Slightly longer (65 s) so
     * a real cancel push still wins the race on the happy path.
     */
    private const val RING_TIMEOUT_MS = 65_000L

    /**
     * Stable per-call notification id so [dismiss] can cancel the ring.
     * Keyed on the BACKEND call id (present in invite, derived from the
     * Stream CID for ring, and present in cancel) so the cancel push can
     * always find the right notification.
     */
    private fun notifId(key: String): Int =
        ("erpcall:$key".hashCode()) and 0x7fffffff

    fun show(context: Context, args: Map<*, *>) {
        val callId = args["callId"]?.toString() ?: ""
        val callCid = args["callCid"]?.toString() ?: ""
        val callerId = args["callerId"]?.toString() ?: ""
        val callerName = args["callerName"]?.toString() ?: "Unknown"
        val isVideo = args["isVideo"] == true
        val baseUrl = args["baseUrl"]?.toString() ?: ""
        val conversationId = args["conversationId"]?.toString() ?: ""
        val conversationName = args["conversationName"]?.toString() ?: ""
        val isGroup = args["isGroup"] == true
        // Dart-supplied JWTs so the Reject receiver can POST without
        // re-decrypting flutter_secure_storage natively (which throws
        // AEADBadTagException on some OEMs). Empty → native falls back to
        // SecureTokenReader.
        val authToken = args["authToken"]?.toString() ?: ""
        val refreshToken = args["refreshToken"]?.toString() ?: ""
        // Caller's public profile-photo URL (absolute). Downloaded off the
        // main thread and shown as the round caller avatar on the ring.
        val avatarUrl = args["avatarUrl"]?.toString() ?: ""

        if (callCid.isEmpty()) {
            Log.w(TAG, "show() skipped — empty callCid")
            return
        }
        Log.i(TAG, "show() callId=$callId callCid=$callCid caller=$callerName video=$isVideo")

        createChannel(context)

        // Prefer the backend callId as the dismiss key; fall back to the
        // CID only if callId wasn't supplied.
        val id = notifId(if (callId.isNotEmpty()) callId else callCid)
        val data = Bundle().apply {
            putString("callId", callId)
            putString("callCid", callCid)
            putString("callerId", callerId)
            putString("callerName", callerName)
            putBoolean("isVideo", isVideo)
            putString("baseUrl", baseUrl)
            putString("conversationId", conversationId)
            putString("conversationName", conversationName)
            putBoolean("isGroup", isGroup)
            putString("authToken", authToken)
            putString("refreshToken", refreshToken)
        }

        // Reject → native broadcast receiver. Killed-app safe: no UI,
        // no Dart, just an HTTP POST in a background thread.
        val rejectIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_REJECT
            putExtra(EXTRA_CALL_DATA, data)
            putExtra(EXTRA_NOTIF_ID, id)
        }
        val rejectPending = PendingIntent.getBroadcast(
            context, id * 3, rejectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )

        // Accept → launch MainActivity (Dart joins the call).
        val acceptPending = PendingIntent.getActivity(
            context, id * 3 + 1, mainActivityIntent(context, data, accept = true),
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )

        // Body tap / full-screen (locked) → MainActivity, in-app sheet.
        val contentPending = PendingIntent.getActivity(
            context, id * 3 + 2, mainActivityIntent(context, data, accept = false),
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )

        val title = if (isGroup && conversationName.isNotEmpty()) conversationName else callerName
        val kind = if (isVideo) "video" else "voice"
        val text = if (isGroup) "$callerName • Incoming group $kind call"
        else "Incoming $kind call"

        // Telephony-style header: the caller is modelled as a [Person] and
        // the Accept / Reject actions are rendered by [CallStyle] as round
        // green / red phone buttons (matching the system dialer's incoming
        // -call look), instead of the plain text "Reject | Accept" actions
        // a vanilla notification shows. CallStyle.forIncomingCall takes the
        // DECLINE intent first, then the ANSWER intent.
        //
        // [callerIcon] is the caller's downloaded profile photo (null until
        // it arrives). Posting is factored into a closure so we can show the
        // ring INSTANTLY without a photo, then re-post the same id with the
        // avatar once the off-thread download completes. setOnlyAlertOnce so
        // the avatar update is silent (no second ring / heads-up).
        fun postNotification(callerIcon: IconCompat?) {
            val callerBuilder = Person.Builder()
                .setName(title)
                .setImportant(true)
            if (callerIcon != null) callerBuilder.setIcon(callerIcon)
            val caller = callerBuilder.build()
            val callStyle = NotificationCompat.CallStyle
                .forIncomingCall(caller, rejectPending, acceptPending)

            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.sym_call_incoming)
                .setStyle(callStyle)
                // CallStyle drives the title from the Person; keep contentText
                // as the "Incoming voice call" subtitle for the collapsed row.
                .setContentText(text)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setOnlyAlertOnce(true)
                .setOngoing(true)
                .setAutoCancel(false)
                // Backend-independent safety net: if NO cancel signal ever
                // reaches this device (caller ended the call but neither the
                // STOMP `call.hangup` nor a Stream/backend end-push was
                // delivered — common when the callee is killed and OEM battery
                // savers drop the wake push), the ring would otherwise hang on
                // screen forever. Auto-expire it after the ring window so it
                // can never outlive a call that's already over. Matches the
                // 60 s ring timeout in CallSignalingService.
                .setTimeoutAfter(RING_TIMEOUT_MS)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(contentPending)
                .setFullScreenIntent(contentPending, true)
            // CallStyle renders the round caller avatar from the Person's
            // icon (set above) — no separate setLargeIcon needed.

            try {
                NotificationManagerCompat.from(context).notify(id, builder.build())
            } catch (e: SecurityException) {
                // POST_NOTIFICATIONS not granted — nothing we can do from here.
                Log.e(TAG, "notify() denied (no POST_NOTIFICATIONS?): ${e.message}")
            }
        }

        // Instant ring (no photo yet) so we never delay the incoming call.
        postNotification(null)

        // Then fetch the caller's avatar off the main thread and re-post the
        // SAME notification with it. Best-effort: any failure just leaves the
        // default caller glyph. Skipped when no URL was supplied.
        if (avatarUrl.isNotEmpty()) {
            Thread {
                val bmp = downloadBitmap(avatarUrl)
                if (bmp != null) {
                    try {
                        postNotification(IconCompat.createWithBitmap(bmp))
                    } catch (e: Exception) {
                        Log.w(TAG, "avatar re-post failed: ${e.message}")
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        // OS-level safety net. `setTimeoutAfter` is ignored by some OEMs
        // (Samsung One UI) on ongoing CATEGORY_CALL notifications, so we
        // ALSO arm an AlarmManager dismiss. This survives the FCM
        // background isolate being torn down right after it posted the
        // ring (a Dart Timer would die with the isolate; the alarm is held
        // by the OS), and it's the only mechanism that clears a stuck ring
        // on a fully-killed callee when NO cancel push is ever delivered.
        scheduleTimeout(context, id)
    }

    fun dismiss(context: Context, key: String) {
        if (key.isEmpty()) return
        val id = notifId(key)
        NotificationManagerCompat.from(context).cancel(id)
        cancelTimeout(context, id)
        Log.i(TAG, "dismiss() key=$key")
    }

    fun dismissById(context: Context, id: Int) {
        if (id < 0) return
        NotificationManagerCompat.from(context).cancel(id)
        cancelTimeout(context, id)
    }

    /**
     * Nuke EVERY call notification this app currently has on screen —
     * regardless of which id or channel posted it.
     *
     * Why this exists: on call end the per-id [dismiss] is not enough.
     *   1. The Stream SDK posts its own ongoing "call" notification
     *      (channel `stream_call_*`) that we don't own and can't cancel by
     *      a known id.
     *   2. Samsung One UI keeps ongoing `CallStyle` (CATEGORY_CALL)
     *      notifications pinned even after a plain `cancel(id)` — they
     *      survive on the lock screen and read to the user as "still
     *      Connected" long after the call actually ended.
     *
     * This enumerates the app's OWN active notifications (getActiveNotifi-
     * cations is package-scoped, never touches other apps), filters to the
     * call ones (CATEGORY_CALL or our / Stream's call channels), and for
     * each: first RE-POSTS a throwaway non-ongoing, auto-cancel
     * notification on the same id+channel — which demotes the sticky
     * ongoing flag One UI is holding onto — then cancels it. The re-post is
     * given a 1 ms timeout and cancelled immediately, so it never visibly
     * renders.
     *
     * Call this on every terminal call path (peer hangup, local hangup,
     * reject, Stream-ended) and on app resume to sweep orphans left behind
     * when the OEM froze/killed the process mid-call.
     */
    fun dismissAllCallNotifications(context: Context) {
        val nmc = NotificationManagerCompat.from(context)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            // Pre-23 can't enumerate; blunt fallback — we only ever post
            // call notifications from this app, so cancelAll is safe.
            try { nmc.cancelAll() } catch (_: Exception) {}
            return
        }
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as? NotificationManager ?: return
        val active = try { nm.activeNotifications } catch (_: Exception) { return }
        var cleared = 0
        for (sbn in active) {
            val n = sbn.notification ?: continue
            val channel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                n.channelId ?: ""
            } else ""
            val isCall = n.category == Notification.CATEGORY_CALL ||
                channel == CHANNEL_ID ||
                channel.startsWith("stream_call")
            if (!isCall) continue
            val id = sbn.id
            // Demote the sticky ongoing flag (Samsung One UI) by replacing
            // the notification with a tame, non-ongoing, auto-cancel stub
            // on the SAME id+channel, then cancel. The stub self-expires in
            // 1 ms so it never renders.
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && channel.isNotEmpty()) {
                    val tame = NotificationCompat.Builder(context, channel)
                        .setSmallIcon(android.R.drawable.sym_call_missed)
                        .setOngoing(false)
                        .setAutoCancel(true)
                        .setTimeoutAfter(1)
                        .build()
                    nmc.notify(id, tame)
                }
            } catch (_: Exception) {}
            try { nmc.cancel(id) } catch (_: Exception) {}
            cancelTimeout(context, id)
            cleared++
        }
        // Reliable nuke: Samsung One UI ignores cancel(id) on ongoing
        // foreground-service / CallStyle call notifications, and the Stream
        // client's FGS notification can be orphaned by a dead process so it
        // never appears in getActiveNotifications above. cancelAll() drops
        // every notification this app owns regardless of id/process. The app
        // only ever posts call notifications, so there's no collateral.
        try { nmc.cancelAll() } catch (_: Exception) {}
        Log.i(TAG, "dismissAllCallNotifications() cleared=$cleared of ${active.size} (+cancelAll)")
    }

    /** Build the (action + id)-keyed PendingIntent the alarm fires. */
    private fun timeoutPending(context: Context, notifId: Int, flags: Int): PendingIntent? {
        val intent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_TIMEOUT
            putExtra(EXTRA_NOTIF_ID, notifId)
        }
        return PendingIntent.getBroadcast(context, notifId, intent, flags)
    }

    /** Arm an AlarmManager dismiss [RING_TIMEOUT_MS] from now. */
    private fun scheduleTimeout(context: Context, notifId: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pending = timeoutPending(
            context, notifId,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        ) ?: return
        val triggerAt = System.currentTimeMillis() + RING_TIMEOUT_MS
        try {
            // `setAndAllowWhileIdle` fires even in Doze and needs NO exact-
            // alarm permission (unlike setExact* on Android 12+). Inexact
            // batching is fine — this is a backstop, not the primary path.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            Log.i(TAG, "scheduleTimeout() id=$notifId in ${RING_TIMEOUT_MS}ms")
        } catch (e: Exception) {
            Log.e(TAG, "scheduleTimeout() failed: ${e.message}")
        }
    }

    /** Cancel a previously-armed dismiss alarm (real cancel won the race). */
    private fun cancelTimeout(context: Context, notifId: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pending = timeoutPending(
            context, notifId,
            PendingIntent.FLAG_NO_CREATE or immutableFlag()
        ) ?: return
        am.cancel(pending)
    }

    private fun mainActivityIntent(context: Context, data: Bundle, accept: Boolean): Intent {
        return Intent().apply {
            setClassName(context.packageName, "${context.packageName}.MainActivity")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            val d = Bundle(data)
            d.putBoolean("accept", accept)
            putExtra(EXTRA_CALL_DATA, d)
        }
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID, "Incoming calls", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Incoming voice and video calls"
            enableVibration(true)
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannel(ch)
    }

    private fun immutableFlag(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

    /**
     * Download the caller's avatar (public `/uploads/avatars/...` URL — no
     * auth needed). Runs on a background thread; returns null on any failure
     * so the ring just keeps its default glyph. Decoded at a modest sample
     * size — the icon is rendered small, no need for a full-res bitmap.
     */
    private fun downloadBitmap(url: String): Bitmap? {
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 4000
                readTimeout = 4000
                instanceFollowRedirects = true
            }
            if (conn.responseCode != HttpURLConnection.HTTP_OK) return null
            conn.inputStream.use { input ->
                BitmapFactory.decodeStream(input)
            }
        } catch (e: Exception) {
            Log.w(TAG, "avatar download failed: ${e.message}")
            null
        } finally {
            try { conn?.disconnect() } catch (_: Exception) {}
        }
    }
}
