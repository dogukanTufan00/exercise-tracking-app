package com.dogukantufan00.exercise_tracking_app

import android.app.Application
import android.os.SystemClock
import com.dogukantufan00.exercise_tracking_app.data.PhoneSyncRepository
import com.dogukantufan00.exercise_tracking_app.data.ThemeSource
import com.dogukantufan00.exercise_tracking_app.data.WorkoutSyncRepository
import com.dogukantufan00.exercise_tracking_app.session.SessionRestTimer
import com.dogukantufan00.exercise_tracking_app.session.vibrateRestFinished
import com.dogukantufan00.exercise_tracking_app.tile.TileUpdater
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/**
 * Uygulama sınıfı: tek [WorkoutSyncRepository] ve [ThemeSource] örneğini oluşturur ve tutar.
 * Ekranlar `(application as WatchApp).syncRepository` ile alır.
 */
class WatchApp : Application() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    lateinit var syncRepository: WorkoutSyncRepository
        private set

    /** Dinlenme sayacı; ekrandan bağımsız (bkz. §15.8). Ajan BE oluşturur. */
    lateinit var restTimer: com.dogukantufan00.exercise_tracking_app.session.RestTimerController
        private set

    /** Telefondaki seçili tema (bkz. §15.7). */
    lateinit var themeSource: ThemeSource
        private set

    override fun onCreate() {
        super.onCreate()
        syncRepository = PhoneSyncRepository(this, scope)
        themeSource = ThemeSource(this, scope)
        restTimer = SessionRestTimer(
            scope = scope,
            clock = { SystemClock.elapsedRealtime() },
            wallClock = { System.currentTimeMillis() },
            vibrate = { vibrateRestFinished(this@WatchApp) },
        )
        // Sayaç hedefi iyimser durumdan gelir; ekran kapalıyken de izlensin diye uygulama kapsamında toplanır (§16.2).
        scope.launch {
            syncRepository.workout.map { it?.rest }.distinctUntilChanged().collect { restTimer.follow(it) }
        }
        TileUpdater.start(
            context = this,
            scope = scope,
            workout = syncRepository.workout,
            program = syncRepository.program,
            theme = themeSource.themeId,
        )
    }
}
