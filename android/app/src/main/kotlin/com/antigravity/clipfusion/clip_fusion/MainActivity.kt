package com.antigravity.clipfusion.clip_fusion

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var methodCallHandler: MethodCallHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val handler = MethodCallHandler(this)
        methodCallHandler = handler

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.antigravity.clipfusion/download")
            .setMethodCallHandler(handler)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.antigravity.clipfusion/download_events")
            .setStreamHandler(handler)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 54321) {
            if (resultCode == RESULT_OK && data != null) {
                val treeUri = data.data
                if (treeUri != null) {
                    try {
                        contentResolver.takePersistableUriPermission(
                            treeUri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            MethodChannel(messenger, "com.antigravity.clipfusion/download")
                                .invokeMethod("onSAFPermissionGranted", treeUri.toString())
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }
        }
    }
}
