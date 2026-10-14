package com.dsh.beadlightboard

import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Display-related platform calls. Flutter's MediaQuery exposes only
        // devicePixelRatio, but true 1:1 physical alignment between the
        // on-screen grid and a transparent pegboard needs the real
        // millimetre-to-pixel relation; keeping the screen awake is also a
        // display concern, so both live on this channel.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPhysicalDpi" -> {
                        val metrics: DisplayMetrics = resources.displayMetrics
                        result.success(
                            mapOf(
                                "xdpi" to metrics.xdpi.toDouble(),
                                "ydpi" to metrics.ydpi.toDouble(),
                                "densityDpi" to metrics.densityDpi,
                            ),
                        )
                    }
                    "setKeepScreenOn" -> {
                        val keepOn = call.argument<Boolean>("on") ?: false
                        runOnUiThread {
                            if (keepOn) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                        }
                        result.success(keepOn)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val CHANNEL_NAME = "bead_light_board/display"
    }
}
