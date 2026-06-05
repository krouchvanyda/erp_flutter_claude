package com.enterprise.erp.erp_callkit

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

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

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setContentText(text)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
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
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel, "Reject", rejectPending
            )
            .addAction(
                android.R.drawable.sym_action_call, "Accept", acceptPending
            )

        try {
            NotificationManagerCompat.from(context).notify(id, builder.build())
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS not granted — nothing we can do from here.
            Log.e(TAG, "notify() denied (no POST_NOTIFICATIONS?): ${e.message}")
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
}
