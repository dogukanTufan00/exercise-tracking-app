package com.dogukantufan00.exercise_tracking_app.session

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.dogukantufan00.exercise_tracking_app.domain.RestCountdown
import com.dogukantufan00.exercise_tracking_app.domain.RestProgress
import com.dogukantufan00.exercise_tracking_app.domain.RestTimer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** Bitiş titreşimi: kısa-kısa-uzun (ms, bekle/titre dizisi). */
private val REST_FINISHED_PATTERN_MS = longArrayOf(0, 120, 100, 120, 100, 400)

/** Ekran güncelleme aralığı (ms); ~5 kez/sn. */
private const val TICK_MILLIS = 200L

/**
 * [RestTimerController] gerçeklemesi (bkz. docs/ARCHITECTURE.md §15.8 madde 1).
 *
 * Bitiş zamanı [clock] (SystemClock.elapsedRealtime) ile tutulur; döngü yalnızca görüntüyü tazeler.
 * Saat ve titreşim enjekte edilir ki JVM'de test edilebilsin.
 *
 * @param scope uygulama kapsamı; döngü burada çalışır.
 * @param clock monotonik saat (ms).
 * @param vibrate süre bitince çağrılır (bitiş titreşimi).
 */
class SessionRestTimer(
    private val scope: CoroutineScope,
    private val clock: () -> Long,
    private val vibrate: () -> Unit,
    private val tickMillis: Long = TICK_MILLIS,
) : RestTimerController {

    /** Çalışan sayaç; [token] her yeni başlatmada artar, eski döngüler kendini durdurur. */
    private class Active(val token: Long, val countdown: RestCountdown)

    private val lock = Any()
    private var active: Active? = null
    private var nextToken = 0L
    private var job: Job? = null

    private val restState = MutableStateFlow<RestProgress?>(null)
    private val finishedFlow = MutableSharedFlow<Unit>(extraBufferCapacity = 1)

    override val rest: StateFlow<RestProgress?> = restState.asStateFlow()
    override val finished: SharedFlow<Unit> = finishedFlow.asSharedFlow()

    override fun start(totalSeconds: Int) {
        synchronized(lock) {
            job?.cancel()
            val token = ++nextToken
            val countdown = RestTimer.start(totalSeconds, clock())
            active = Active(token, countdown)
            restState.value = RestTimer.progress(countdown, clock())
            job = scope.launch { run(token) }
        }
    }

    override fun adjust(deltaSeconds: Int) {
        var finishedNow = false
        synchronized(lock) {
            val current = active ?: return
            val now = clock()
            val adjusted = RestTimer.adjust(current.countdown, deltaSeconds)
            if (RestTimer.isFinished(adjusted, now)) {
                finishedNow = true
                active = null
                job?.cancel()
                job = null
                restState.value = null
            } else {
                active = Active(current.token, adjusted)
                restState.value = RestTimer.progress(adjusted, now)
            }
        }
        if (finishedNow) announceFinished()
    }

    override fun skip() {
        synchronized(lock) {
            active = null
            job?.cancel()
            job = null
            restState.value = null
        }
    }

    /** Sayaç bitene kadar görüntüyü tazeler; bittiğinde bir kez titretir ve yayar. */
    private suspend fun run(token: Long) {
        while (true) {
            val finishedNow = synchronized(lock) {
                val current = active?.takeIf { it.token == token } ?: return
                val now = clock()
                if (RestTimer.isFinished(current.countdown, now)) {
                    active = null
                    job = null
                    restState.value = null
                    true
                } else {
                    restState.value = RestTimer.progress(current.countdown, now)
                    false
                }
            }
            if (finishedNow) {
                announceFinished()
                return
            }
            delay(tickMillis)
        }
    }

    private fun announceFinished() {
        vibrate()
        finishedFlow.tryEmit(Unit)
    }
}

/**
 * Bitiş titreşimi. Android 12+ `VibratorManager.defaultVibrator`, öncesinde `Vibrator` kullanılır.
 * Cihazda motor yoksa sessizce çıkar.
 */
fun vibrateRestFinished(context: Context) {
    val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        context.getSystemService(VibratorManager::class.java)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Vibrator::class.java)
    } ?: return
    if (!vibrator.hasVibrator()) return
    vibrator.vibrate(VibrationEffect.createWaveform(REST_FINISHED_PATTERN_MS, -1))
}
