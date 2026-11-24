package com.dogukantufan00.exercise_tracking_app.session

import com.dogukantufan00.exercise_tracking_app.domain.DisplayRest
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SessionRestTimerTest {

    /** Sahte monotonik saat, duvar saati ve titreşim sayacı. Saatler sanal zamanla birlikte ilerletilir. */
    private class Fake {
        var now = 0L
        var wall = 1_700_000_000_000L
        var vibrations = 0
    }

    private fun TestScope.createTimer(fake: Fake): SessionRestTimer =
        SessionRestTimer(
            scope = backgroundScope,
            clock = { fake.now },
            wallClock = { fake.wall },
            vibrate = { fake.vibrations++ },
            zone = ZoneOffset.UTC,
            tickMillis = 200L,
        )

    /** Hem sahte saatleri hem sanal zamanı [ms] kadar ilerletir. */
    private fun TestScope.advance(fake: Fake, ms: Long) {
        fake.now += ms
        fake.wall += ms
        advanceTimeBy(ms)
        runCurrent()
    }

    /** [inMs] sonra biten bir hedef (bitiş anı, sahte duvar saatine göre). */
    private fun target(fake: Fake, restId: String, endsInMs: Long, totalSeconds: Int) = DisplayRest(
        restId = restId,
        endsAt = LocalDateTime.ofInstant(Instant.ofEpochMilli(fake.wall + endsInMs), ZoneOffset.UTC),
        totalSeconds = totalSeconds,
    )

    /** Bitiş olaylarını sayan bir toplayıcı; SharedFlow'a abone olunmadan yayın kaybolur. */
    private fun TestScope.countFinished(timer: SessionRestTimer): IntArray {
        val counter = IntArray(1)
        backgroundScope.launch(start = CoroutineStart.UNDISPATCHED) {
            timer.finished.collect { counter[0]++ }
        }
        return counter
    }

    @Test
    fun follow_showsRemainingTime_andCountsDown() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)

        timer.follow(target(fake, "a", 90_000, 90))
        assertEquals(90, timer.rest.value?.totalSeconds)
        assertEquals(90, timer.rest.value?.remainingSeconds)

        advance(fake, 1_000)
        assertEquals(89, timer.rest.value?.remainingSeconds)
    }

    @Test
    fun sameTargetAgain_doesNotRestart() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)
        val same = target(fake, "a", 90_000, 90)

        timer.follow(same)
        advance(fake, 10_000)
        timer.follow(same)

        assertEquals(80, timer.rest.value?.remainingSeconds)
    }

    @Test
    fun changedEndSameRestId_continuesWithoutSecondRestart() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)
        val finished = countFinished(timer)

        timer.follow(target(fake, "a", 60_000, 60))
        advance(fake, 30_000)
        // ±15 sn: aynı restId, bitiş 15 sn sonraya kaydı (toplam 75 sn; kalan 45 sn).
        timer.follow(target(fake, "a", 45_000, 75))
        assertEquals(45, timer.rest.value?.remainingSeconds)

        advance(fake, 44_000)
        assertEquals(1, timer.rest.value?.remainingSeconds)
        assertEquals(0, fake.vibrations)

        advance(fake, 2_000)
        assertNull(timer.rest.value)
        assertEquals(1, fake.vibrations)
        assertEquals(1, finished[0])
    }

    @Test
    fun naturalFinish_vibratesOnce_emitsFinished_andClearsState() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)
        val finished = countFinished(timer)

        timer.follow(target(fake, "a", 90_000, 90))
        advance(fake, 89_000)
        assertEquals(0, fake.vibrations)
        assertEquals(0, finished[0])

        advance(fake, 2_000)
        assertNull(timer.rest.value)
        assertEquals(1, fake.vibrations)
        assertEquals(1, finished[0])
    }

    @Test
    fun nullTarget_stopsWithoutVibrationOrFinishEvent() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)
        val finished = countFinished(timer)

        timer.follow(target(fake, "a", 60_000, 60))
        timer.follow(null)
        advance(fake, 120_000)

        assertNull(timer.rest.value)
        assertEquals(0, fake.vibrations)
        assertEquals(0, finished[0])
    }

    @Test
    fun nullTargetJustBeforeEnd_countsAsFinished_andVibratesOnce() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)
        val finished = countFinished(timer)

        // Telefonun saati biraz ileride: sayacı saatinkinden ~0,5 sn önce kaldırır.
        timer.follow(target(fake, "a", 60_000, 60))
        advance(fake, 59_500)
        timer.follow(null)
        advance(fake, 5_000)

        assertNull(timer.rest.value)
        assertEquals(1, fake.vibrations)
        assertEquals(1, finished[0])
    }

    @Test
    fun alreadyFinishedTarget_isNotShownNorVibrated() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)

        timer.follow(target(fake, "a", -1_000, 60))
        assertNull(timer.rest.value)

        advance(fake, 5_000)
        assertEquals(0, fake.vibrations)
    }

    @Test
    fun sameRestIdFinishedAgain_vibratesOnlyOnce_butStillEmits() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)
        val finished = countFinished(timer)

        timer.follow(target(fake, "a", 60_000, 60))
        advance(fake, 60_001)
        assertEquals(1, fake.vibrations)

        // Aynı restId yeni bir bitiş anıyla geri gelirse (ör. telefondan yeniden ayarlandı) yine titremez.
        timer.follow(target(fake, "a", 30_000, 30))
        assertEquals(30, timer.rest.value?.remainingSeconds)
        advance(fake, 30_001)

        assertEquals(1, fake.vibrations)
        assertEquals(2, finished[0])
    }

    @Test
    fun newRestId_vibratesAgain() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)

        timer.follow(target(fake, "a", 60_000, 60))
        advance(fake, 60_001)
        assertEquals(1, fake.vibrations)

        timer.follow(target(fake, "b", 30_000, 30))
        advance(fake, 30_001)
        assertEquals(2, fake.vibrations)
    }
}
