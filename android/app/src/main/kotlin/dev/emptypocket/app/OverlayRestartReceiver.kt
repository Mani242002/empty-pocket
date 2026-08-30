package dev.emptypocket.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver listening for device boot or application update to maintain
 * background readiness and sticky overlay availability.
 */
class OverlayRestartReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "OverlayRestartReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "onReceive triggered with action: $action")
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val bubbleEnabled = prefs.getBoolean("flutter.floating_bubble_enabled", false)
            Log.d(TAG, "Bubble enabled preference: $bubbleEnabled")
            // System is ready for Flutter engine initialization upon app or overlay trigger
        }
    }
}
