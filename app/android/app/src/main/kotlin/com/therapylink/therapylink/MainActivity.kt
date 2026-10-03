package com.therapylink.therapylink

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity extends FlutterFragmentActivity (required for local_auth's biometric fragments).
 *
 * Exposes a "therapylink/privacy" MethodChannel so the Dart side can toggle FLAG_SECURE, which
 * prevents screenshots and hides the app in the recents switcher while app lock is on.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "therapylink/privacy")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    if (call.argument<Boolean>("secure") == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
