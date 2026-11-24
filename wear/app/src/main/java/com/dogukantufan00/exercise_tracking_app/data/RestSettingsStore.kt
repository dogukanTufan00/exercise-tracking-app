package com.dogukantufan00.exercise_tracking_app.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.dogukantufan00.exercise_tracking_app.domain.REST_DEFAULT_SECONDS
import com.dogukantufan00.exercise_tracking_app.domain.RestTimer
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.restSettingsDataStore: DataStore<Preferences> by preferencesDataStore(name = "rest_settings")

/**
 * Telefondan kopyalanan dinlenme süresinin (saniye) saatteki önbelleği (§16.2).
 * Açılışta ilk değer olarak kullanılır; telefon bağlı değilken de son değer geçerlidir. Hiç yoksa 90 sn.
 */
class RestSettingsStore(private val dataStore: DataStore<Preferences>) {

    /** Önbellekteki süre; hiç kaydedilmediyse [REST_DEFAULT_SECONDS]. */
    val restSeconds: Flow<Int> = dataStore.data.map { prefs ->
        RestTimer.clampSeconds(prefs[KEY_REST_SECONDS] ?: REST_DEFAULT_SECONDS)
    }

    /** Telefondan gelen süreyi kaydeder (15 – 600 sn aralığına sınırlanır). */
    suspend fun save(seconds: Int) {
        dataStore.edit { prefs -> prefs[KEY_REST_SECONDS] = RestTimer.clampSeconds(seconds) }
    }

    companion object {
        private val KEY_REST_SECONDS = intPreferencesKey("rest_seconds")

        /** Uygulama başına tek DataStore örneği kullanılır; her çağrı aynı dosyanın örneğini sarar. */
        fun create(context: Context): RestSettingsStore =
            RestSettingsStore(context.applicationContext.restSettingsDataStore)
    }
}
