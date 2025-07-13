package com.example.frontend

import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Intent
import android.os.IBinder
import android.os.ParcelUuid
import android.util.Log
import java.nio.charset.Charset
import java.util.UUID

import androidx.localbroadcastmanager.content.LocalBroadcastManager

class BleService : Service() {

    companion object {
        const val ACTION_DEVICE_FOUND = "com.example.frontend.ACTION_DEVICE_FOUND"
        const val EXTRA_TEMP_ID = "com.example.frontend.EXTRA_TEMP_ID"
    }

    private val bluetoothAdapter: BluetoothAdapter by lazy {
        val bluetoothManager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothManager.adapter
    }

    private val advertiser: BluetoothLeAdvertiser by lazy {
        bluetoothAdapter.bluetoothLeAdvertiser
    }

    private val scanner: BluetoothLeScanner by lazy {
        bluetoothAdapter.bluetoothLeScanner
    }

    // iOSと共通のサービスUUID
    private val serviceUuid = ParcelUuid.fromString("00001234-0000-1000-8000-00805F9B34FB")

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("BleService", "onStartCommand: ${intent?.action}")

        when (intent?.action) {
            "START" -> {
                val tempId = intent.getStringExtra("tempId")
                if (tempId != null) {
                    startBleOperations(tempId)
                }
            }
            "STOP" -> {
                stopBleOperations()
            }
        }
        // サービスが強制終了された場合に再起動する
        return START_STICKY
    }

    private fun startBleOperations(tempId: String) {
        Log.d("BleService", "Starting BLE operations with tempId: $tempId")
        // TODO: スキャンとアドバタイズを開始するロジックを実装
        startScanning()
        startAdvertising(tempId)
    }

    private fun stopBleOperations() {
        Log.d("BleService", "Stopping BLE operations")
        // TODO: スキャンとアドバタイズを停止するロジックを実装
        stopScanning()
        stopAdvertising()
    }

    private fun startAdvertising(tempId: String) {
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(serviceUuid)
            .addServiceData(serviceUuid, tempId.toByteArray(Charset.forName("UTF-8")))
            .build()

        try {
            advertiser.startAdvertising(settings, data, advertiseCallback)
        } catch (e: SecurityException) {
            Log.e("BleService", "Bluetooth permission not granted for advertising", e)
        }
    }

    private fun stopAdvertising() {
        try {
            advertiser.stopAdvertising(advertiseCallback)
        } catch (e: SecurityException) {
            Log.e("BleService", "Bluetooth permission not granted for stopping advertising", e)
        }
    }

    private fun startScanning() {
        val filter = ScanFilter.Builder()
            .setServiceUuid(serviceUuid)
            .build()
        val filters = listOf(filter)

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        try {
            scanner.startScan(filters, settings, scanCallback)
        } catch (e: SecurityException) {
            Log.e("BleService", "Bluetooth permission not granted for scanning", e)
        }
    }

    private fun stopScanning() {
        try {
            scanner.stopScan(scanCallback)
        } catch (e: SecurityException) {
            Log.e("BleService", "Bluetooth permission not granted for stopping scan", e)
        }
    }

    // --- Callbacks ---

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            Log.d("BleService", "Advertising started successfully")
        }

        override fun onStartFailure(errorCode: Int) {
            Log.e("BleService", "Advertising failed to start with error code: $errorCode")
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            result?.let {
                // TODO: 発見したデバイスの情報を処理し、Flutterに通知する
                val scanRecord = it.scanRecord?.serviceData?.get(serviceUuid)
                if (scanRecord != null) {
                    val foundTempId = String(scanRecord, Charset.forName("UTF-8"))
                    Log.d("BleService", "Found device with tempId: $foundTempId, RSSI: ${it.rssi}")
                    // ここでMainActivityにブロードキャストを送信する
                    val intent = Intent(ACTION_DEVICE_FOUND).apply {
                        putExtra(EXTRA_TEMP_ID, foundTempId)
                    }
                    LocalBroadcastManager.getInstance(this@BleService).sendBroadcast(intent)
                }
            }
        }

        override fun onScanFailed(errorCode: Int) {
            Log.e("BleService", "Scan failed with error code: $errorCode")
        }
    }
}