package com.dogukantufan00.exercise_tracking_app

import android.app.Application
import com.dogukantufan00.exercise_tracking_app.data.PhoneSyncRepository
import com.dogukantufan00.exercise_tracking_app.data.WorkoutSyncRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/**
 * Uygulama sınıfı: tek [WorkoutSyncRepository] örneğini oluşturur ve tutar.
 * Ekranlar `(application as WatchApp).syncRepository` ile alır.
 */
class WatchApp : Application() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    lateinit var syncRepository: WorkoutSyncRepository
        private set

    override fun onCreate() {
        super.onCreate()
        syncRepository = PhoneSyncRepository(this, scope)
    }
}
