package com.enterprise.erp.erp_callkit

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
    const val EXTRA_NOTIF_ID = "erp_notif_id"

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
    }

    fun dismiss(context: Context, key: String) {
        if (key.isEmpty()) return
        NotificationManagerCompat.from(context).cancel(notifId(key))
        Log.i(TAG, "dismiss() key=$key")
    }

    fun dismissById(context: Context, id: Int) {
        if (id < 0) return
        NotificationManagerCompat.from(context).cancel(id)
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
