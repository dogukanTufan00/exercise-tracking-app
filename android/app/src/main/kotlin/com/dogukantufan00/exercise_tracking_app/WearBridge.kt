package com.dogukantufan00.exercise_tracking_app

import android.content.Context
import android.net.Uri
import android.util.Log
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ile saat köprüsü (MethodChannel `exercise_tracker/wear`): anlık durum, tema, program ve işlenen olayları
 * Data Layer'a yazar; olay kuyruğunu Flutter'a verir. Hem uygulamanın motoru ([MainActivity]) hem de
 * saat olaylarını arka planda işleyen ekransız motor ([WearBackgroundRunner]) aynı köprüyü kullanır.
 */
object WearBridge {
    private const val TAG = "WearBridge"
    const val METHOD_CHANNEL = "exercise_tracker/wear"
    private const val SNAPSHOT_PATH = "/workout/active"
    private const val THEME_PATH = "/settings/theme"
    private const val THEME_KEY = "themeId"
    private const val PROGRAM_PATH = "/program/active"
    private const val APPLIED_PATH = "/events/applied"
    private const val REST_SETTINGS_PATH = "/settings/rest"
    private const val REST_SECONDS_KEY = "restSeconds"
    private const val JSON_KEY = "json"

    /**
     * Köprüyü [messenger]'a bağlar. [onBackgroundDone] yalnızca ekransız motorda verilir: Dart işini bitirince
     * `backgroundDone` çağırır. Uygulamanın motorunda ([onBackgroundDone] null) ekransız motor çalışırken
     * `drainEvents` boş döner; böylece bir olay iki motorda birden işlenmez (motor bitince kuyruk yeniden bildirilir).
     */
    fun attach(context: Context, messenger: BinaryMessenger, onBackgroundDone: (() -> Unit)? = null) {
        val app = context.applicationContext
        WearEventQueue.init(app)
        val isBackground = onBackgroundDone != null

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "publishSnapshot" -> putJson(app, SNAPSHOT_PATH, JSON_KEY, call.arguments as? String, "Anlık durum", result)
                "clearSnapshot" -> delete(app, SNAPSHOT_PATH, "Anlık durum", result)
                "publishTheme" -> putJson(app, THEME_PATH, THEME_KEY, call.arguments as? String, "Tema", result)
                "publishProgram" -> putJson(app, PROGRAM_PATH, JSON_KEY, call.arguments as? String, "Program", result)
                "clearProgram" -> delete(app, PROGRAM_PATH, "Program", result)
                "publishApplied" -> putJson(app, APPLIED_PATH, JSON_KEY, call.arguments as? String, "İşlenen olaylar", result)
                "publishRestSettings" -> putRestSeconds(app, (call.arguments as? Number)?.toInt(), result)
                "drainEvents" -> result.success(
                    if (!isBackground && WearBackgroundRunner.isRunning) emptyList() else WearEventQueue.list(),
                )
                "ackEvents" -> {
                    val ids = (call.arguments as? List<*>)?.filterIsInstance<String>().orEmpty()
                    WearEventQueue.ack(ids)
                    result.success(null)
                }
                "backgroundDone" -> {
                    result.success(null)
                    onBackgroundDone?.invoke()
                }
                else -> result.notImplemented()
            }
        }
    }

    /** [value] metnini [path] DataItem'ında [key] anahtarına yazar (acil). Hata yalnızca günlüğe yazılır. */
    private fun putJson(
        context: Context,
        path: String,
        key: String,
        value: String?,
        label: String,
        result: MethodChannel.Result,
    ) {
        if (value == null) {
            result.error("bad_args", "$label için metin bekleniyordu", null)
            return
        }
        val request = PutDataMapRequest.create(path).run {
            dataMap.putString(key, value)
            asPutDataRequest().setUrgent()
        }
        Wearable.getDataClient(context)
            .putDataItem(request)
            .addOnFailureListener { e -> Log.w(TAG, "$label yazılamadı", e) }
        result.success(null)
    }

    /** Dinlenme süresini (sn) [REST_SETTINGS_PATH] DataItem'ında [REST_SECONDS_KEY] (int) olarak yazar (§16.2). */
    private fun putRestSeconds(context: Context, seconds: Int?, result: MethodChannel.Result) {
        if (seconds == null) {
            result.error("bad_args", "Dinlenme süresi için sayı bekleniyordu", null)
            return
        }
        val request = PutDataMapRequest.create(REST_SETTINGS_PATH).run {
            dataMap.putInt(REST_SECONDS_KEY, seconds)
            asPutDataRequest().setUrgent()
        }
        Wearable.getDataClient(context)
            .putDataItem(request)
            .addOnFailureListener { e -> Log.w(TAG, "Dinlenme ayarı yazılamadı", e) }
        result.success(null)
    }

    /** [path] DataItem'ını siler. Hata yalnızca günlüğe yazılır. */
    private fun delete(context: Context, path: String, label: String, result: MethodChannel.Result) {
        val uri = Uri.Builder()
            .scheme(PutDataRequest.WEAR_URI_SCHEME)
            .path(path)
            .build()
        Wearable.getDataClient(context)
            .deleteDataItems(uri)
            .addOnFailureListener { e -> Log.w(TAG, "$label silinemedi", e) }
        result.success(null)
    }
}
