package com.example.project_elara // (Change this to your package name)

import io.flutter.plugin.common.EventChannel
import java.util.Timer
import java.util.TimerTask
import kotlin.random.Random
import android.os.Handler // Import Handler
import android.os.Looper  // Import Looper

class HealthStreamHandler : EventChannel.StreamHandler {

    private var timer: Timer? = null
    private var eventSink: EventChannel.EventSink? = null

    // This is called when Flutter *starts* listening
    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        this.eventSink = sink
    }

    // This is called when Flutter *stops* listening
    override fun onCancel(arguments: Any?) {
        this.eventSink = null
        stopStreaming()
    }

    // This is called by our MethodChannel
    fun startStreaming() {
        if (timer != null) return // Already running
        
        // --- THIS IS THE SIMULATION ---
        // A real app would use the Health Connect API
        timer = Timer()
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                // Generate fake HR and HRV data
                val fakeHR = Random.nextDouble(60.0, 85.0)
                val fakeHRV = Random.nextDouble(40.0, 65.0)
                
                // Create the data map to send to Flutter
                val data = mapOf(
                    "timestamp" to (System.currentTimeMillis() / 1000),
                    "hr" to fakeHR,
                    "hrv" to fakeHRV
                )
                
                // Send the data to Flutter on the main thread
                // This is required!
                Handler(Looper.getMainLooper()).post {
                    eventSink?.success(data)
                }
            }
        }, 0, 1000) // Send data every 1 second
    }

    // This is called by our MethodChannel
    fun stopStreaming() {
        timer?.cancel()
        timer = null
    }
}