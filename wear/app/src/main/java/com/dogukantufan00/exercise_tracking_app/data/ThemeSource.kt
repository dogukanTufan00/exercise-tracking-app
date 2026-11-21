package com.dogukantufan00.exercise_tracking_app.data

import android.content.Context
import android.net.Uri
import android.util.Log
import com.dogukantufan00.exercise_tracking_app.domain.WatchThemeId
import com.dogukantufan00.exercise_tracking_app.domain.watchThemeIdOf
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

/**
 * Telefonda seçili temayı izler (bkz. docs/ARCHITECTURE.md §15.7).
 *
 * Son tema SharedPreferences'tan senkron okunur (ilk kare doğru renkte çizilsin); sonra `/settings/theme`
 * DataItem'ı okunur ve değişiklikler dinlenir. Her yeni değer SharedPreferences'a yazılır.
 */
class ThemeSource(
    context: Context,
    private val scope: CoroutineScope,
) {
    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val dataClient: DataClient = Wearable.getDataClient(appContext)

    private val themeFlow = MutableStateFlow(watchThemeIdOf(prefs.getString(KEY_THEME_ID, null)))

    /** Seçili tema. Başlangıçta son kaydedilen (ya da varsayılan) temadır. */
    val themeId: StateFlow<WatchThemeId> = themeFlow.asStateFlow()

    init {
        dataClient.addListener(DataClient.OnDataChangedListener { buffer ->
            try {
                buffer.forEach { event ->
                    if (event.dataItem.uri.path == THEME_PATH) handleThemeEvent(event)
                }
            } finally {
                buffer.release()
            }
        })
        scope.launch { loadCurrentTheme() }
    }

    /** Tema DataItem'ını uygulamanın açılışında okur. */
    private suspend fun loadCurrentTheme() {
        val name = withContext(Dispatchers.IO) {
            runCatching {
                val buffer = dataClient.getDataItems(themeUri()).await()
                try {
                    buffer.firstOrNull()?.let { decodeThemeName(it) }
                } finally {
                    buffer.release()
                }
            }.onFailure { Log.w(TAG, "Tema okunamadı", it) }.getOrNull()
        }
        if (name != null) applyTheme(name)
    }

    /** Silinen DataItem temayı değiştirmez; yeni değer [decodeThemeName] ile çözülür. */
    private fun handleThemeEvent(event: DataEvent) {
        if (event.type == DataEvent.TYPE_DELETED) return
        decodeThemeName(event.dataItem)?.let { applyTheme(it) }
    }

    /** Tema adını kaydeder ve akışa verir. Bilinmeyen ad [watchThemeIdOf] ile varsayılana düşer. */
    private fun applyTheme(name: String) {
        prefs.edit().putString(KEY_THEME_ID, name).apply()
        themeFlow.value = watchThemeIdOf(name)
    }

    /** DataItem'daki tema adını okur; eksikse null. */
    private fun decodeThemeName(item: DataItem): String? =
        runCatching { DataMapItem.fromDataItem(item).dataMap.getString(THEME_KEY) }.getOrNull()

    private fun themeUri(): Uri = Uri.Builder()
        .scheme(PutDataRequest.WEAR_URI_SCHEME)
        .path(THEME_PATH)
        .build()

    private companion object {
        const val PREFS_NAME = "watch_theme"
        const val KEY_THEME_ID = "themeId"
        const val TAG = "ThemeSource"
    }
}
