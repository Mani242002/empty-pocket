package dev.emptypocket.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log
import flutter.overlay.window.flutter_overlay_window.OverlayService
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Enhanced StickyOverlayService extending flutter_overlay_window's OverlayService.
 * Overrides onStartCommand with START_STICKY and onTaskRemoved to ensure the
 * 24/7 floating bubble overlay stays alive even when the app is swiped from Recent Apps.
 * Ensures immediate foreground promotion in onCreate to prevent Android 14+
 * ForegroundServiceDidNotStartInTimeException on cold boot.
 * Pre-warms the FlutterEngine for overlayMain if null to prevent NullPointerException
 * on cold boot or device restart.
 */
class StickyOverlayService : OverlayService() {

    companion object {
        private const val TAG = "StickyOverlayService"
        // Unified with flutter_overlay_window internal constants to prevent dual notifications
        private const val CHANNEL_ID = "Overlay Channel"
        private const val NOTIFICATION_ID = 4579
        private const val CACHED_TAG = "myCachedEngine"
        private const val DEFAULT_XY = -6
    }

    override fun onCreate() {
        // Android 14+ requirement: promote to foreground with FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        // BEFORE calling super.onCreate() or pre-warming engines to prevent ForegroundServiceDidNotStartInTimeException.
        promoteToForegroundSafely()
        ensureFlutterEngineInitialized()
        super.onCreate()
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
            } catch (e: Exception) {
                Log.w(TAG, "Promote to foreground fallback: ${e.message}")
            }
        }
    }

    private fun ensureFlutterEngineInitialized() {
        try {
            if (FlutterEngineCache.getInstance().get(CACHED_TAG) == null) {
                Log.i(TAG, "Pre-warming FlutterEngine for overlayMain on cold start")
                val flutterLoader = FlutterInjector.instance().flutterLoader()
                if (!flutterLoader.initialized()) {
                    flutterLoader.startInitialization(applicationContext)
                }
                flutterLoader.ensureInitializationComplete(applicationContext, null)

                val engineGroup = FlutterEngineGroup(applicationContext)
                val entrypoint = DartExecutor.DartEntrypoint(
                    flutterLoader.findAppBundlePath(),
                    "overlayMain"
                )
                val engine = engineGroup.createAndRunEngine(applicationContext, entrypoint)
                FlutterEngineCache.getInstance().put(CACHED_TAG, engine)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error warming FlutterEngine for overlay: ${e.message}", e)
        }
    }

    private fun applyWindowSetup(intent: Intent?) {
        try {
            val windowSetupClass = Class.forName("flutter.overlay.window.flutter_overlay_window.WindowSetup")
            val heightField = windowSetupClass.getDeclaredField("height").apply { isAccessible = true }
            val widthField = windowSetupClass.getDeclaredField("width").apply { isAccessible = true }
            val enableDragField = windowSetupClass.getDeclaredField("enableDrag").apply { isAccessible = true }
            val titleField = windowSetupClass.getDeclaredField("overlayTitle").apply { isAccessible = true }
            val contentField = windowSetupClass.getDeclaredField("overlayContent").apply { isAccessible = true }

            val density = resources.displayMetrics.density
            val defaultSizePx = (60 * density).toInt()

            val w = intent?.getIntExtra("width", defaultSizePx) ?: defaultSizePx
            val h = intent?.getIntExtra("height", defaultSizePx) ?: defaultSizePx
            val drag = intent?.getBooleanExtra("enableDrag", true) ?: true
            val title = intent?.getStringExtra("overlayTitle") ?: "EmptyPocket Quick-Add"
            val content = intent?.getStringExtra("overlayContent") ?: "Tap floating bubble to log expenses"

            widthField.setInt(null, if (w > 0) w else defaultSizePx)
            heightField.setInt(null, if (h > 0) h else defaultSizePx)
            enableDragField.setBoolean(null, drag)
            titleField.set(null, title)
            contentField.set(null, content)
        } catch (e: Exception) {
            Log.w(TAG, "WindowSetup reflection initialization fallback: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        promoteToForegroundSafely()
        ensureFlutterEngineInitialized()
        applyWindowSetup(intent)

        // Guard against null intent on OS START_STICKY recovery so super.onStartCommand does not crash
        // and correctly adds the flutterView to the WindowManager with default coordinates.
        val safeIntent = intent ?: Intent(this, StickyOverlayService::class.java).apply {
            putExtra("startX", DEFAULT_XY)
            putExtra("startY", DEFAULT_XY)
        }

        try {
            super.onStartCommand(safeIntent, flags, startId)
        } catch (e: Exception) {
            Log.e(TAG, "Error in super.onStartCommand: ${e.message}", e)
        }
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val bubbleEnabled = prefs.getBoolean("flutter.floating_bubble_enabled", false)
            if (bubbleEnabled) {
                val restartIntent = Intent(applicationContext, StickyOverlayService::class.java)
                restartIntent.setPackage(packageName)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(restartIntent)
                } else {
                    startService(restartIntent)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Sticky restart on task removed failed: ${e.message}")
        }
        super.onTaskRemoved(rootIntent)
    }
}

