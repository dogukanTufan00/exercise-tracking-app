package com.dogukantufan00.exercise_tracking_app

import android.app.Application
import com.dogukantufan00.exercise_tracking_app.data.WorkoutSyncRepository

/**
 * Uygulama sınıfı: tek [WorkoutSyncRepository] örneğini oluşturur ve tutar.
 * Ekranlar `(application as WatchApp).syncRepository` ile alır.
 */
class WatchApp : Application() {
    lateinit var syncRepository: WorkoutSyncRepository
        private set

    override fun onCreate() {
        super.onCreate()
        // Ajan AC: PhoneSyncRepository'yi burada oluştur ve başlat.
        syncRepository = TODO("Ajan AC: PhoneSyncRepository")
    }
}
