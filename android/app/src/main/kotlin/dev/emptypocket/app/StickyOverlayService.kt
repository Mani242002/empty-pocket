package dev.emptypocket.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log

class StickyOverlayService : Service() {
    companion object {
        private const val TAG = "StickyOverlayService"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "onTaskRemoved: Task removed, scheduling overlay persistence")
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val bubbleEnabled = prefs.getBoolean("flutter.floating_bubble_enabled", false)
            if (bubbleEnabled) {
                val restartIntent = Intent(applicationContext, OverlayRestartReceiver::class.java).apply {
                    action = "dev.emptypocket.app.RESTART_OVERLAY"
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    applicationContext,
                    888,
                    restartIntent,
                    PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
                )
                val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                alarmManager?.set(
                    AlarmManager.ELAPSED_REALTIME,
                    SystemClock.elapsedRealtime() + 250,
                    pendingIntent
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onTaskRemoved", e)
        }
    }
}
