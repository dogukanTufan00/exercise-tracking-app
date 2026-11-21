package com.dogukantufan00.exercise_tracking_app

import android.app.Application
import com.dogukantufan00.exercise_tracking_app.data.PhoneSyncRepository
import com.dogukantufan00.exercise_tracking_app.data.ThemeSource
import com.dogukantufan00.exercise_tracking_app.data.WorkoutSyncRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/**
 * Uygulama sınıfı: tek [WorkoutSyncRepository] ve [ThemeSource] örneğini oluşturur ve tutar.
 * Ekranlar `(application as WatchApp).syncRepository` ile alır.
 */
class WatchApp : Application() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    lateinit var syncRepository: WorkoutSyncRepository
        private set

    /** Telefondaki seçili tema (bkz. §15.7). */
    lateinit var themeSource: ThemeSource
        private set

    override fun onCreate() {
        super.onCreate()
        syncRepository = PhoneSyncRepository(this, scope)
        themeSource = ThemeSource(this, scope)
    }
}
