package com.dogukantufan00.exercise_tracking_app.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.builtins.ListSerializer

private val Context.pendingEventsDataStore: DataStore<Preferences> by preferencesDataStore(name = "pending_events")

/**
 * Saatte henüz telefona onaylanmamış olayların kalıcı kuyruğu (bkz. docs/ARCHITECTURE.md §15.6).
 *
 * Liste tek bir anahtarda, [ProtocolJson] ile kodlanmış JSON dizisi olarak tutulur. Okunamayan veri boş liste sayılır.
 */
class PendingEventStore(context: Context) {
    private val dataStore = context.applicationContext.pendingEventsDataStore

    /** Bekleyen olaylar; her değişiklikte yeni liste yayınlanır. */
    val events: Flow<List<WatchEvent>> = dataStore.data.map { prefs -> decode(prefs[EVENTS_KEY]) }

    /** Kuyruğu [transform] ile atomik olarak dönüştürür. */
    suspend fun update(transform: (List<WatchEvent>) -> List<WatchEvent>) {
        dataStore.edit { prefs ->
            val updated = transform(decode(prefs[EVENTS_KEY]))
            prefs[EVENTS_KEY] = ProtocolJson.encodeToString(EVENT_LIST_SERIALIZER, updated)
        }
    }

    private fun decode(raw: String?): List<WatchEvent> {
        if (raw == null) return emptyList()
        return runCatching { ProtocolJson.decodeFromString(EVENT_LIST_SERIALIZER, raw) }
            .getOrDefault(emptyList())
    }

    private companion object {
        val EVENTS_KEY = stringPreferencesKey("pending_events_json")
        val EVENT_LIST_SERIALIZER = ListSerializer(WatchEvent.serializer())
    }
}
