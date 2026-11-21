package com.dogukantufan00.exercise_tracking_app

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Saatten gelen mesajları (yol `/event`) alır, yerel kuyruğa yazar ve Flutter'a haber verir.
 *
 * Uygulama kapalıyken de çalışır: Data Layer, manifest'teki intent-filter ile bu servisi başlatır.
 */
class PhoneWearListenerService : WearableListenerService() {

    override fun onCreate() {
        super.onCreate()
        WearEventQueue.init(this)
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != EVENT_PATH) return
        WearEventQueue.add(String(messageEvent.data, Charsets.UTF_8))
        WearEventNotifier.notifyAvailable()
    }

    private companion object {
        /** Saatin olay mesajlarını gönderdiği yol (bkz. docs/ARCHITECTURE.md §15.4). */
        const val EVENT_PATH = "/event"
    }
}
