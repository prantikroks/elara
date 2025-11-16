package com.example.project_elara // (Change this to your package name)

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel // Import EventChannel
import android.content.Intent

// Import our new HealthStreamHandler (we will create this)
import com.example.project_elara.HealthStreamHandler // (Change to your package name)

class MainActivity: FlutterActivity() {
    private val AR_CHANNEL = "com.elara.app/ar"
    private val HEALTH_METHOD_CHANNEL = "com.elara.app/health_method"
    private val HEALTH_EVENT_CHANNEL = "com.elara.app/health_event"

    // Create an instance of our stream handler
    // This assumes HealthStreamHandler exists and implements EventChannel.StreamHandler
    private val healthStreamHandler = HealthStreamHandler()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // --- AR CHANNEL (from before) ---
        val arChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AR_CHANNEL)
        arChannel.setMethodCallHandler { call, result ->
            if (call.method == "launchAR") {
                // When we get the call, launch our new native ARActivity
                // This assumes 'ARActivity.kt' exists.
                val intent = Intent(this, ARActivity::class.java)
                startActivity(intent)
                result.success(null) // Send "success" back to Flutter
            } else {
                result.notImplemented()
            }
        }
        
        // --- HEALTH METHOD CHANNEL (Start/Stop) ---
        val healthMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HEALTH_METHOD_CHANNEL)
        healthMethodChannel.setMethodCallHandler { call, result ->
            if (call.method == "startHealthStream") {
                // This assumes your 'HealthStreamHandler' has a 'startStreaming()' function
                healthStreamHandler.startStreaming()
                result.success(null)
            } else if (call.method == "stopHealthStream") {
                // This assumes your 'HealthStreamHandler' has a 'stopStreaming()' function
                healthStreamHandler.stopStreaming()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        
        // --- HEALTH EVENT CHANNEL (The Stream) ---
        val healthEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, HEALTH_EVENT_CHANNEL)
        // Set the stream handler
        healthEventChannel.setStreamHandler(healthStreamHandler)
    }
}