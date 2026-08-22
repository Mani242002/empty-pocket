package dev.emptypocket.app

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val OVERLAY_CHANNEL = "dev.emptypocket.app/overlay"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openQuickAdd" -> {
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    if (intent != null) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        intent.putExtra("action", "quick_add")
                        startActivity(intent)
                        methodChannel?.invokeMethod("triggerQuickAdd", null)
                        result.success(true)
                    } else {
                        result.error("LAUNCH_FAILED", "Could not create launch intent", null)
                    }
                }
                "minimizeApp" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = intent.getStringExtra("action")
        if (action == "quick_add") {
            methodChannel?.invokeMethod("triggerQuickAdd", null)
        }
    }
}
