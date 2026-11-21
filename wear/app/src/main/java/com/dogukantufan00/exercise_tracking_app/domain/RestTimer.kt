package com.dogukantufan00.exercise_tracking_app.domain

import kotlin.math.max

/*
 * Dinlenme sayacının saf mantığı (Android import etmez, JVM testlidir).
 * Bitiş zamanı monotonik saat (elapsedRealtime, ms) ile tutulur; ekran güncellemesi süreyi kaydırmaz.
 */

const val REST_MIN_SECONDS = 15
const val REST_MAX_SECONDS = 600
const val REST_STEP_SECONDS = 15
const val REST_DEFAULT_SECONDS = 90

/** Çalışan sayaç: toplam süre ve bitiş zamanı. */
data class RestCountdown(val totalSeconds: Int, val endAtMillis: Long)

/** Ekranda gösterilen anlık durum. [remainingFraction] 1'den 0'a iner (dairesel ilerleme için). */
data class RestProgress(val totalSeconds: Int, val remainingSeconds: Int, val remainingFraction: Float)

object RestTimer {
    /** Süreyi 15 sn – 10 dk aralığına sınırlar. */
    fun clampSeconds(seconds: Int): Int = seconds.coerceIn(REST_MIN_SECONDS, REST_MAX_SECONDS)

    /** Süreyi [steps] adım (her adım 15 sn) kadar değiştirir ve sınırlar. */
    fun stepSeconds(seconds: Int, steps: Int): Int = clampSeconds(seconds + steps * REST_STEP_SECONDS)

    /** [nowMillis] anında başlayan sayaç. */
    fun start(totalSeconds: Int, nowMillis: Long): RestCountdown {
        val total = clampSeconds(totalSeconds)
        return RestCountdown(total, nowMillis + total * 1000L)
    }

    /** Kalan süre (ms); bitmişse 0. */
    fun remainingMillis(countdown: RestCountdown, nowMillis: Long): Long =
        max(0L, countdown.endAtMillis - nowMillis)

    /** Süre bittiyse true. */
    fun isFinished(countdown: RestCountdown, nowMillis: Long): Boolean =
        remainingMillis(countdown, nowMillis) == 0L

    /** Ekran durumu. Kalan saniye yukarı yuvarlanır: 90 sn'nin ilk anı "1:30" gösterir. */
    fun progress(countdown: RestCountdown, nowMillis: Long): RestProgress {
        val remainingMs = remainingMillis(countdown, nowMillis)
        val remainingSeconds = ((remainingMs + 999L) / 1000L).toInt()
        val totalMs = countdown.totalSeconds * 1000L
        val fraction = if (totalMs <= 0L) 0f else (remainingMs.toFloat() / totalMs).coerceIn(0f, 1f)
        return RestProgress(countdown.totalSeconds, remainingSeconds, fraction)
    }

    /**
     * Çalışan sayacı [deltaSeconds] kadar uzatır ya da kısaltır (bitiş zamanı ve toplam birlikte kayar).
     * Sonuç bitmiş olabilir; çağıran [isFinished] ile kontrol eder.
     */
    fun adjust(countdown: RestCountdown, deltaSeconds: Int): RestCountdown =
        RestCountdown(
            totalSeconds = max(1, countdown.totalSeconds + deltaSeconds),
            endAtMillis = countdown.endAtMillis + deltaSeconds * 1000L,
        )
}
