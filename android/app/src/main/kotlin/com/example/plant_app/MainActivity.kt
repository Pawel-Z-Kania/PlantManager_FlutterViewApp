package com.example.plant_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAlertChannel()
    }

    // Kanał musi istnieć przed pierwszym pushem; id zgodne z channel_id wysyłanym przez backend.
    private fun createAlertChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            ALERT_CHANNEL_ID,
            "Alarmy doniczek",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Utrata sygnału doniczki i konieczność podlania"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private companion object {
        const val ALERT_CHANNEL_ID = "pot_alerts"
    }
}
