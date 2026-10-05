package dev.emptypocket.app

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val OVERLAY_CHANNEL = "dev.emptypocket.app/overlay"
    private val BATTERY_CHANNEL = "dev.emptypocket.app/battery"
    private var methodChannel: MethodChannel? = null
    private var batteryChannel: MethodChannel? = null
    private var pendingAction: String? = null
    private var isClientReady: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup dynamic shortcut preserving task backstack
        setupDynamicShortcut()

        // Check for cold-start intent
        handleIntent(intent)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "clientReady" -> {
                    isClientReady = true
                    if (pendingAction == "quick_add") {
                        pendingAction = null
                        methodChannel?.invokeMethod("triggerQuickAdd", null)
                    }
                    result.success(true)
                }
                "minimizeApp" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                "startStickyOverlay" -> {
                    try {
                        val width = call.argument<Int>("width")
                        val height = call.argument<Int>("height")
                        val enableDrag = call.argument<Boolean>("enableDrag") ?: true
                        val overlayTitle = call.argument<String>("overlayTitle") ?: "EmptyPocket Quick-Add"
                        val overlayContent = call.argument<String>("overlayContent") ?: "Tap floating bubble to log expenses"

                        val serviceIntent = Intent(this, StickyOverlayService::class.java).apply {
                            if (width != null) putExtra("width", width)
                            if (height != null) putExtra("height", height)
                            putExtra("enableDrag", enableDrag)
                            putExtra("overlayTitle", overlayTitle)
                            putExtra("overlayContent", overlayContent)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_START_FAILED", "Failed to start StickyOverlayService: ${e.message}", null)
                    }
                }
                "stopStickyOverlay" -> {
                    try {
                        val serviceIntent = Intent(this, StickyOverlayService::class.java)
                        stopService(serviceIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_STOP_FAILED", "Failed to stop StickyOverlayService: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        batteryChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
        batteryChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                            try {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                // Fallback to generic settings screen if direct dialog is restricted by OEM
                                try {
                                    val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                    startActivity(fallbackIntent)
                                    result.success(true)
                                } catch (fallbackEx: Exception) {
                                    result.error("INTENT_FAILED", "Could not open battery settings", fallbackEx.message)
                                }
                            }
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "openBatterySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_FAILED", "Could not open battery settings", e.message)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra("action")
        val intentAction = intent.action
        if (action == "quick_add" || intentAction == "dev.emptypocket.app.QUICK_ADD") {
            if (isClientReady) {
                methodChannel?.invokeMethod("triggerQuickAdd", null)
            } else {
                pendingAction = "quick_add"
            }
        }
    }

    private fun setupDynamicShortcut() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            try {
                val shortcutManager = getSystemService(ShortcutManager::class.java)
                if (shortcutManager != null) {
                    val intent = Intent(this, MainActivity::class.java).apply {
                        action = "dev.emptypocket.app.QUICK_ADD"
                        putExtra("action", "quick_add")
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val shortcut = ShortcutInfo.Builder(this, "quick_add")
                        .setShortLabel(getString(R.string.quick_add_short))
                        .setLongLabel(getString(R.string.quick_add_long))
                        .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
                        .setIntent(intent)
                        .build()
                    shortcutManager.dynamicShortcuts = listOf(shortcut)
                }
            } catch (e: Exception) {
                // Ignore if shortcuts unsupported
            }
        }
    }
}
