package com.example.frontend

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.Registrar

class BleManager(private val context: Context, private val eventSink: EventChannel.EventSink?) : MethodChannel.MethodCallHandler {
    companion object {
        const val SERVICE_UUID = "0000C0DE-0000-1000-8000-00805F9B34FB"
        var tids: List<String> = listOf()
        var currentTidIndex = 0
        var tidHandler: Handler? = null
        var scanHandler: Handler? = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startBleService" -> {
                tids = (call.argument<List<String>>("tids") ?: listOf())
                currentTidIndex = 0
                startAdvertising()
                startScanning()
                result.success(null)
            }
            "stopBleService" -> {
                stopAdvertising()
                stopScanning()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startAdvertising() {
        // TODO: 実装（BluetoothLeAdvertiserを利用）
        updateAdvertisingTid()
        tidHandler = Handler(Looper.getMainLooper())
        tidHandler?.postDelayed(object : Runnable {
            override fun run() {
                currentTidIndex = (currentTidIndex + 1) % tids.size
                updateAdvertisingTid()
                tidHandler?.postDelayed(this, 15 * 60 * 1000)
            }
        }, 15 * 60 * 1000)
    }

    private fun stopAdvertising() {
        // TODO: 実装
        tidHandler?.removeCallbacksAndMessages(null)
    }

    private fun updateAdvertisingTid() {
        // TODO: 実装
    }

    private fun startScanning() {
        scanHandler = Handler(Looper.getMainLooper())
        scanHandler?.post(object : Runnable {
            override fun run() {
                performScan()
                scanHandler?.postDelayed(this, 5 * 60 * 1000)
            }
        })
    }

    private fun stopScanning() {
        scanHandler?.removeCallbacksAndMessages(null)
    }

    private fun performScan() {
        // TODO: 実装（BluetoothLeScannerを利用）
        Handler(Looper.getMainLooper()).postDelayed({
            // スキャン結果をeventSinkで送信（ダミー実装）
            val dummyResult: List<Map<String, Any>> = listOf()
            eventSink?.success(dummyResult)
        }, 10 * 1000)
    }
} 