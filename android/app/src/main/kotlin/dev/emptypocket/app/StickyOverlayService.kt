package dev.emptypocket.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import flutter.overlay.window.flutter_overlay_window.OverlayService

/**
 * Enhanced StickyOverlayService extending flutter_overlay_window's OverlayService.
 * Overrides onStartCommand with START_STICKY and onTaskRemoved to ensure the
 * 24/7 floating bubble overlay stays alive even when the app is swiped from Recent Apps.
 * Ensures immediate foreground promotion in onCreate to prevent Android 14+
 * ForegroundServiceDidNotStartInTimeException on cold boot.
 */
class StickyOverlayService : OverlayService() {

    companion object {
        private const val CHANNEL_ID = "emptypocket_sticky_overlay"
        private const val NOTIFICATION_ID = 1002
    }

    override fun onCreate() {
        super.onCreate()
        promoteToForegroundSafely()
    }

    private fun promoteToForegroundSafely() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "EmptyPocket Quick-Add Bubble",
                    NotificationManager.IMPORTANCE_MIN
                ).apply {
                    description = "Maintains 24/7 background availability for quick expense logging"
                    setShowBadge(false)
                }
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                manager?.createNotificationChannel(channel)

                val notification = Notification.Builder(this, CHANNEL_ID)
                    .setSmallIcon(applicationInfo.icon)
                    .setContentTitle("EmptyPocket Quick-Add")
                    .setContentText("Tap floating bubble to log expenses")
                    .setOngoing(true)
                    .build()

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            } catch (_: Exception) {
                // Defensive fallback: flutter_overlay_window will also attempt startForeground
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        promoteToForegroundSafely()
        super.onStartCommand(intent, flags, startId)
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val restartIntent = Intent(applicationContext, StickyOverlayService::class.java)
            restartIntent.setPackage(packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(restartIntent)
            } else {
                startService(restartIntent)
            }
        } catch (_: Exception) {
            // Ignored - system handles restart via sticky flag
        }
        super.onTaskRemoved(rootIntent)
    }
}

