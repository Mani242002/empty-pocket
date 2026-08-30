package dev.emptypocket.app

import android.content.Intent
import flutter.overlay.window.flutter_overlay_window.OverlayService

/**
 * Enhanced StickyOverlayService extending flutter_overlay_window's OverlayService.
 * Overrides onStartCommand with START_STICKY and onTaskRemoved to ensure the
 * 24/7 floating bubble overlay stays alive even when the app is swiped from Recent Apps.
 */
class StickyOverlayService : OverlayService() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val restartIntent = Intent(applicationContext, StickyOverlayService::class.java)
            restartIntent.setPackage(packageName)
            startService(restartIntent)
        } catch (_: Exception) {
            // Ignored - system handles restart via sticky flag
        }
        super.onTaskRemoved(rootIntent)
    }
}
