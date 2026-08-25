package com.medaayu.medaayu

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.medaayu.medaayu/sos_widget"
    private var startWithSos = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Detect if activity was launched with ACTION_SOS (Cold start)
        if (intent?.action == "com.medaayu.ACTION_SOS") {
            startWithSos = true
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Detect if widget is tapped while app is running (Warm start)
        if (intent.action == "com.medaayu.ACTION_SOS") {
            startWithSos = true
            flutterEngine?.let {
                MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("triggerSosFromWidget", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkLaunchNotification") {
                result.success(startWithSos)
                startWithSos = false // reset flag
            } else {
                result.notImplemented()
            }
        }
    }
}
