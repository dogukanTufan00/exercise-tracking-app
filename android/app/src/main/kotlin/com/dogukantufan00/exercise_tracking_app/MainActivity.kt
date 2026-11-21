package com.dogukantufan00.exercise_tracking_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    /** Flutter ile saat köprüsü ([WearBridge]) ve "yeni olay var" bildirimi (EventChannel). */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        WearBridge.attach(this, messenger)

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                WearEventNotifier.sink = events
            }

            override fun onCancel(arguments: Any?) {
                WearEventNotifier.sink = null
            }
        })
    }

    private companion object {
        const val EVENT_CHANNEL = "exercise_tracker/wear/events"
    }
}
