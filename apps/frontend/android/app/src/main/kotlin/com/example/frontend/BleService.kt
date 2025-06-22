package com.example.frontend

import android.app.Service
import android.content.Intent
import android.os.IBinder

class BleService : Service() {
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        // TODO: Foreground通知とBLE処理の開始
    }

    override fun onDestroy() {
        super.onDestroy()
        // TODO: BLE処理の停止
    }
} 