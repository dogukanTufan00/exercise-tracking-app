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
 * Saatte ayarlanan varsayılan dinlenme süresi (saniye, 15 – 600 aralığında, varsayılan 90).
 * Telefondan bağımsızdır; yalnızca saatte saklanır.
 */
class RestSettingsStore(private val dataStore: DataStore<Preferences>) {

    /** Kayıtlı dinlenme süresi; hiç ayarlanmadıysa [REST_DEFAULT_SECONDS]. */
    val restSeconds: Flow<Int> = dataStore.data.map { prefs ->
        RestTimer.clampSeconds(prefs[KEY_REST_SECONDS] ?: REST_DEFAULT_SECONDS)
    }

    /** Süreyi [steps] adım (15 sn) değiştirir. Okuma ve yazma tek işlemde yapılır, hızlı çevirmede kayma olmaz. */
    suspend fun stepRestSeconds(steps: Int) {
        dataStore.edit { prefs ->
            prefs[KEY_REST_SECONDS] = RestTimer.stepSeconds(prefs[KEY_REST_SECONDS] ?: REST_DEFAULT_SECONDS, steps)
        }
    }

    companion object {
        private val KEY_REST_SECONDS = intPreferencesKey("rest_seconds")

        /** Uygulama başına tek DataStore örneği kullanır. */
        fun create(context: Context): RestSettingsStore =
            RestSettingsStore(context.applicationContext.restSettingsDataStore)
    }
}
