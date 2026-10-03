package com.therapylink.therapylink

import android.app.ActivityManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED
import android.os.PowerManager
import android.os.StatFs
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity extends FlutterFragmentActivity (required for local_auth's biometric fragments).
 *
 * Exposes two MethodChannels:
 *
 * 1. "therapylink/privacy" — toggles FLAG_SECURE so the screen is excluded from
 *    screenshots and the system recents switcher while app lock is on.
 *
 * 2. "com.therapylink/power_info" — returns device power/RAM information so the
 *    presence widgets can choose the correct render rung (video HD / video low /
 *    poster). Invoked with getPowerInfo → map with keys:
 *      - totalMemoryMb (Int)   : total device RAM in megabytes
 *      - batterySaver (Boolean): whether Battery Saver / Low Power mode is active
 *      - dataSaver (Boolean)   : whether Data Saver (background data restriction) is on
 *
 * 3. "com.therapylink/storage" - freeBytes(path) returns the bytes free to this app on the disk
 *    holding path, so the safety model's download can check for room before it starts.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Privacy channel ──────────────────────────────────────────────────
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

        // ── Power-info channel ───────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.therapylink/power_info")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPowerInfo" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

                        val memInfo = ActivityManager.MemoryInfo()
                        am?.getMemoryInfo(memInfo)
                        val totalMb = (memInfo.totalMem / (1024L * 1024L)).toInt()

                        val batterySaver = pm?.isPowerSaveMode ?: false

                        val dataSaver = if (cm != null) {
                            cm.restrictBackgroundStatus == RESTRICT_BACKGROUND_STATUS_ENABLED
                        } else {
                            false
                        }

                        result.success(
                            mapOf(
                                "totalMemoryMb" to totalMb,
                                "batterySaver" to batterySaver,
                                "dataSaver" to dataSaver,
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Storage channel ──────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.therapylink/storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "freeBytes") {
                    try {
                        val path = call.argument<String>("path") ?: filesDir.path
                        result.success(StatFs(path).availableBytes)
                    } catch (e: IllegalArgumentException) {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
