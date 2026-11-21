package com.dogukantufan00.exercise_tracking_app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Kuyruğa yeni olay eklendiğinde Flutter'a haber verir (EventChannel `exercise_tracker/wear/events`).
 *
 * [sink] Flutter dinlemiyorsa `null`dır; o durumda bildirim sessizce atlanır, olaylar kuyrukta kalır.
 */
object WearEventNotifier {
    /** Flutter'ın dinlediği olay akışı; dinleme yoksa `null`. */
    @Volatile
    var sink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    /** Flutter'a "yeni olay var" bildirir; çağrı iş parçacığından bağımsızdır. */
    fun notifyAvailable() {
        mainHandler.post { sink?.success(null) }
    }
}
