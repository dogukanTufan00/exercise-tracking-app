package com.dogukantufan00.exercise_tracking_app

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Saatten gelen ham olay JSON'larının yerel kuyruğu (SharedPreferences, `wear_event_queue`).
 *
 * Uygulama kapalıyken de olay kaybolmasın diye [PhoneWearListenerService] olayları buraya yazar;
 * Flutter tarafı [list] ile okur, işledikten sonra [ack] ile siler.
 * Önce [init] çağrılmalıdır.
 */
object WearEventQueue {
    private const val PREFS_NAME = "wear_event_queue"
    private const val KEY_EVENTS = "events"

    /** Kuyrukta en fazla bu kadar olay tutulur; taşarsa en eski atılır. */
    private const val MAX_EVENTS = 500

    @Volatile
    private var prefs: SharedPreferences? = null

    /** Kuyruğu verilen bağlamın uygulama bağlamıyla açar. Tekrar çağrılması zararsızdır. */
    fun init(context: Context) {
        if (prefs == null) {
            prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
    }

    /**
     * Ham olay JSON'unu kuyruğa ekler.
     * JSON bozuksa, `eventId` yoksa ya da aynı id zaten kuyruktaysa hiçbir şey yapmaz.
     */
    @Synchronized
    fun add(json: String) {
        val store = prefs ?: return
        val eventId = eventIdOf(json) ?: return
        val events = readArray(store)
        for (i in 0 until events.length()) {
            if (eventIdOf(events.optString(i)) == eventId) return
        }
        events.put(json)
        val overflow = events.length() - MAX_EVENTS
        val trimmed = if (overflow > 0) {
            JSONArray().also { out ->
                for (i in overflow until events.length()) out.put(events.get(i))
            }
        } else {
            events
        }
        writeArray(store, trimmed)
    }

    /** Kuyruktaki ham olay JSON'larını gelme sırasıyla döner. Kuyruktan silmez. */
    @Synchronized
    fun list(): List<String> {
        val store = prefs ?: return emptyList()
        val events = readArray(store)
        return List(events.length()) { i -> events.optString(i) }
    }

    /** Verilen id'li olayları kuyruktan siler. */
    @Synchronized
    fun ack(eventIds: List<String>) {
        val store = prefs ?: return
        if (eventIds.isEmpty()) return
        val ids = eventIds.toSet()
        val events = readArray(store)
        val kept = JSONArray()
        for (i in 0 until events.length()) {
            val json = events.optString(i)
            val id = eventIdOf(json)
            if (id == null || id !in ids) kept.put(json)
        }
        writeArray(store, kept)
    }

    /** `eventId` alanını döner; JSON bozuksa ya da alan boşsa `null`. */
    private fun eventIdOf(json: String): String? = try {
        JSONObject(json).optString("eventId").takeIf { it.isNotEmpty() }
    } catch (e: org.json.JSONException) {
        null
    }

    private fun readArray(store: SharedPreferences): JSONArray {
        val raw = store.getString(KEY_EVENTS, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (e: org.json.JSONException) {
            JSONArray()
        }
    }

    private fun writeArray(store: SharedPreferences, events: JSONArray) {
        store.edit().putString(KEY_EVENTS, events.toString()).apply()
    }
}
