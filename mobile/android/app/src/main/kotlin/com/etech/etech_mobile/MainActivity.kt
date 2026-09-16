package com.etech.etech_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    /**
     * Make the notification channel the shop's pushes are sent to.
     *
     * From Android 8 a notification must name a channel that already
     * exists, and one naming a channel that does not is dropped by the
     * system without a word — no error, no entry in the tray, nothing in
     * logcat pointing at the cause. The Edge Function sends every message
     * with `channel_id: "etech_orders"`, so that channel has to be created
     * here first, by the app, before any message arrives.
     *
     * Created on every launch rather than once: createNotificationChannel
     * is idempotent, and the alternative is remembering whether a
     * particular install has ever done it. Re-creating an existing channel
     * does not reset the choices a customer has made about it — Android
     * keeps those, deliberately, so an app cannot un-mute itself.
     *
     * It lives in Kotlin rather than Dart because the channel has to exist
     * whether or not Flutter is running. A notification arriving at a shut
     * app is handled by the Firebase SDK inside a process that never starts
     * the Dart engine, so a channel created from Dart would exist only on
     * handsets that had already opened the app — which is exactly the case
     * push is for.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "etech_orders",
                "Order updates",
                // HIGH so it appears as a heads-up banner rather than
                // arriving silently in the tray. This is news the customer
                // asked to be interrupted by: their payment cleared, or
                // their machine is on the counter waiting for them.
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description =
                    "Payment approved or rejected, and when an order is ready to collect or on its way."
            }

            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }
}
