package com.enterprise.erp.erp_mobile

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    /** Matches IncomingCallNotifier.EXTRA_CALL_DATA in the erp_callkit plugin. */
    private val callDataExtra = "erp_call_data"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        maybeShowOverLockscreen(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        maybeShowOverLockscreen(intent)
    }

    /**
     * When MainActivity is launched by the native incoming-call
     * notification's full-screen / body / Accept intent (it carries the
     * `erp_call_data` bundle), turn the screen on and show OVER the
     * keyguard so the user actually sees the in-app incoming-call UI on a
     * locked device. Without this the activity launches behind the lock
     * screen and nothing appears until the user manually unlocks.
     *
     * Only applied for call launches — a normal launcher start never
     * carries this extra, so the app keeps the standard lock behaviour.
     */
    private fun maybeShowOverLockscreen(intent: Intent?) {
        val isCall = intent?.hasExtra(callDataExtra) == true
        if (!isCall) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            // Ask the system to dismiss the keyguard so the Accept/Reject
            // controls are immediately tappable.
            val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            km?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    android.view.WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }
}
