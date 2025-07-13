package com.example.frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.content.Context
import androidx.localbroadcastmanager.content.LocalBroadcastManager

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.example.campus_connect/ble"
    private val eventChannelName = "com.example.campus_connect/ble_events"

    private var eventSink: EventChannel.EventSink? = null

    private val deviceFoundReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == BleService.ACTION_DEVICE_FOUND) {
                val tempId = intent.getStringExtra(BleService.EXTRA_TEMP_ID)
                eventSink?.success(tempId)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannelのセットアップ
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBleService" -> {
                    val tempId = call.argument<String>("tempId")
                    val serviceIntent = Intent(this, BleService::class.java).apply {
                        action = "START"
                        putExtra("tempId", tempId)
                    }
                    startService(serviceIntent)
                    result.success(null)
                }
                "stopBleService" -> {
                    val serviceIntent = Intent(this, BleService::class.java).apply {
                        action = "STOP"
                    }
                    startService(serviceIntent)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // EventChannelのセットアップ
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    val filter = IntentFilter(BleService.ACTION_DEVICE_FOUND)
                    LocalBroadcastManager.getInstance(this@MainActivity).registerReceiver(deviceFoundReceiver, filter)
                }

                override fun onCancel(arguments: Any?) {
                    LocalBroadcastManager.getInstance(this@MainActivity).unregisterReceiver(deviceFoundReceiver)
                    eventSink = null
                }
            }
        )
    }
}
