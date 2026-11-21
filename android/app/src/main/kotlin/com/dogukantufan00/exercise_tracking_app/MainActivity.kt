package com.dogukantufan00.exercise_tracking_app

import android.net.Uri
import android.util.Log
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /** Flutter ile saat köprüsü: anlık durum yazma, olay kuyruğu, olay bildirimi. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WearEventQueue.init(this)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "publishSnapshot" -> publishSnapshot(call.arguments as? String, result)
                "clearSnapshot" -> clearSnapshot(result)
                "publishTheme" -> publishTheme(call.arguments as? String, result)
                "drainEvents" -> result.success(WearEventQueue.list())
                "ackEvents" -> {
                    val ids = (call.arguments as? List<*>)?.filterIsInstance<String>().orEmpty()
                    WearEventQueue.ack(ids)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                WearEventNotifier.sink = events
            }

            override fun onCancel(arguments: Any?) {
                WearEventNotifier.sink = null
            }
        })
    }

    /** Anlık durum JSON'unu `/workout/active` DataItem'ına yazar. Hata yalnızca günlüğe yazılır. */
    private fun publishSnapshot(json: String?, result: MethodChannel.Result) {
        if (json == null) {
            result.error("bad_args", "publishSnapshot için metin bekleniyordu", null)
            return
        }
        val request = PutDataMapRequest.create(SNAPSHOT_PATH).run {
            dataMap.putString("json", json)
            asPutDataRequest().setUrgent()
        }
        Wearable.getDataClient(this)
            .putDataItem(request)
            .addOnFailureListener { e -> Log.w(TAG, "Anlık durum yazılamadı", e) }
        result.success(null)
    }

    /** `/workout/active` DataItem'ını siler. Hata yalnızca günlüğe yazılır. */
    private fun clearSnapshot(result: MethodChannel.Result) {
        val uri = Uri.Builder()
            .scheme(PutDataRequest.WEAR_URI_SCHEME)
            .path(SNAPSHOT_PATH)
            .build()
        Wearable.getDataClient(this)
            .deleteDataItems(uri)
            .addOnFailureListener { e -> Log.w(TAG, "Anlık durum silinemedi", e) }
        result.success(null)
    }

    /** Seçili tema adını `/settings/theme` DataItem'ına yazar (bkz. §15.7). Hata yalnızca günlüğe yazılır. */
    private fun publishTheme(themeId: String?, result: MethodChannel.Result) {
        if (themeId == null) {
            result.error("bad_args", "publishTheme için metin bekleniyordu", null)
            return
        }
        val request = PutDataMapRequest.create(THEME_PATH).run {
            dataMap.putString(THEME_KEY, themeId)
            asPutDataRequest().setUrgent()
        }
        Wearable.getDataClient(this)
            .putDataItem(request)
            .addOnFailureListener { e -> Log.w(TAG, "Tema yazılamadı", e) }
        result.success(null)
    }

    private companion object {
        const val TAG = "WearBridge"
        const val METHOD_CHANNEL = "exercise_tracker/wear"
        const val EVENT_CHANNEL = "exercise_tracker/wear/events"
        const val SNAPSHOT_PATH = "/workout/active"
        const val THEME_PATH = "/settings/theme"
        const val THEME_KEY = "themeId"
    }
}
