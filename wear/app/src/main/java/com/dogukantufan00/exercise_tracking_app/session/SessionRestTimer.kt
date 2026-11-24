package com.dogukantufan00.exercise_tracking_app.session

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.dogukantufan00.exercise_tracking_app.domain.DisplayRest
import com.dogukantufan00.exercise_tracking_app.domain.RestCountdown
import com.dogukantufan00.exercise_tracking_app.domain.RestProgress
import com.dogukantufan00.exercise_tracking_app.domain.RestTimer
import java.time.ZoneId
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

/** Telefonun kaldırdığı sayaç bitişe bu kadar (ms) yakınsa bitmiş sayılır ve titrer. */
private const val FINISH_GRACE_MILLIS = 2_000L

/** Ekran güncelleme aralığı (ms); ~5 kez/sn. */
private const val TICK_MILLIS = 200L

/** Titreşen sayaç kimliklerinin tutulduğu son kayıt sayısı (en fazla bir titreşim için yeterli). */
private const val BUZZED_KEEP = 16

/**
 * [RestTimerController] gerçeklemesi (bkz. docs/ARCHITECTURE.md §16.2).
 *
 * Telefon ve saatin ortak hedefini izler. Bitiş anı yerel saatten monotonik saate ([clock]) çevrilir; döngü yalnızca
 * görüntüyü tazeler. Saatler ve titreşim enjekte edilir ki JVM'de test edilebilsin.
 *
 * Titreşim kuralı: bir restId için en fazla bir kez, yalnızca sayaç izlenirken süre bittiyse titrer. Bitmiş bir hedef
 * (ör. eski ya da geç gelen) titretmez.
 *
 * @param scope uygulama kapsamı; döngü burada çalışır.
 * @param clock monotonik saat (ms), ör. SystemClock.elapsedRealtime.
 * @param wallClock duvar saati (epoch ms), ör. System.currentTimeMillis; hedefin bitiş anını çevirmek için.
 * @param vibrate süre bitince çağrılır (bitiş titreşimi).
 * @param zone [DisplayRest.endsAt] yerel saatinin saat dilimi.
 */
class SessionRestTimer(
    private val scope: CoroutineScope,
    private val clock: () -> Long,
    private val wallClock: () -> Long,
    private val vibrate: () -> Unit,
    private val zone: ZoneId = ZoneId.systemDefault(),
    private val tickMillis: Long = TICK_MILLIS,
) : RestTimerController {

    /** Çalışan sayaç; [token] her yeni izlemede artar, eski döngüler kendini durdurur. */
    private class Active(val token: Long, val restId: String, val countdown: RestCountdown)

    private val lock = Any()
    private var followed: DisplayRest? = null
    private var active: Active? = null
    private var nextToken = 0L
    private var job: Job? = null

    /** Titreşen sayaçların kimlikleri; bir restId için en fazla bir titreşim. */
    private val buzzed = ArrayDeque<String>()

    private val restState = MutableStateFlow<RestProgress?>(null)
    private val finishedFlow = MutableSharedFlow<Unit>(extraBufferCapacity = 1)

    override val rest: StateFlow<RestProgress?> = restState.asStateFlow()
    override val finished: SharedFlow<Unit> = finishedFlow.asSharedFlow()

    override fun follow(target: DisplayRest?) {
        var finishedEarly = false
        synchronized(lock) {
            if (target == followed) return
            followed = target
            job?.cancel()
            job = null
            val previous = active
            active = null
            if (target == null) {
                restState.value = null
                // Telefon kendi saatine göre bitirip sayacı kaldırdıysa (iki cihazın saati arasında küçük fark olur),
                // saat sayacı birkaç yüz ms erken kalkar. Bitişe çok az kala kalkan sayaç bitmiş sayılır ve titrer.
                if (previous != null &&
                    RestTimer.remainingMillis(previous.countdown, clock()) <= FINISH_GRACE_MILLIS &&
                    previous.restId !in buzzed
                ) {
                    rememberBuzzed(previous.restId)
                    finishedEarly = true
                }
            }
        }
        if (finishedEarly) {
            vibrate()
            finishedFlow.tryEmit(Unit)
            return
        }
        if (target == null) return
        synchronized(lock) {
            if (target != followed) return
            val now = clock()
            val endAtWall = target.endsAt.atZone(zone).toInstant().toEpochMilli()
            val countdown = RestCountdown(target.totalSeconds, now + (endAtWall - wallClock()))
            // Bitmiş bir hedef gösterilmez ve titretilmez.
            if (RestTimer.isFinished(countdown, now)) {
                restState.value = null
                return
            }
            val token = ++nextToken
            active = Active(token, target.restId, countdown)
            restState.value = RestTimer.progress(countdown, now)
            job = scope.launch { run(token) }
        }
    }

    /** Sayaç bitene kadar görüntüyü tazeler; bittiğinde (ilk kez ise) titretir, yayar ve döner. */
    private suspend fun run(token: Long) {
        while (true) {
            // null: sayaç hâlâ çalışıyor. Aksi halde sayaç bitti; değer, titreşilip titrenmeyeceğini söyler.
            val shouldVibrate: Boolean? = synchronized(lock) {
                val current = active?.takeIf { it.token == token } ?: return
                val now = clock()
                if (RestTimer.isFinished(current.countdown, now)) {
                    active = null
                    job = null
                    restState.value = null
                    val firstTime = current.restId !in buzzed
                    if (firstTime) rememberBuzzed(current.restId)
                    firstTime
                } else {
                    restState.value = RestTimer.progress(current.countdown, now)
                    null
                }
            }
            if (shouldVibrate != null) {
                if (shouldVibrate) vibrate()
                finishedFlow.tryEmit(Unit)
                return
            }
            delay(tickMillis)
        }
    }

    /** Titreşen kimliği kaydeder; listeyi [BUZZED_KEEP] ile sınırlar. Yalnızca [lock] içinden çağrılır. */
    private fun rememberBuzzed(restId: String) {
        buzzed.addLast(restId)
        while (buzzed.size > BUZZED_KEEP) buzzed.removeFirst()
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
