package com.dogukantufan00.exercise_tracking_app.session

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

    /** Sahte saat ve titreşim sayacı. Saat, sanal zamanla birlikte ilerletilir. */
    private class Fake {
        var now = 0L
        var vibrations = 0
    }

    private fun TestScope.createTimer(fake: Fake): SessionRestTimer =
        SessionRestTimer(
            scope = backgroundScope,
            clock = { fake.now },
            vibrate = { fake.vibrations++ },
            tickMillis = 200L,
        )

    /** Hem sahte saati hem sanal zamanı [ms] kadar ilerletir. */
    private fun TestScope.advance(fake: Fake, ms: Long) {
        fake.now += ms
        advanceTimeBy(ms)
        runCurrent()
    }

    /** Bitiş olaylarını sayan bir toplayıcı; SharedFlow'a abone olunmadan yayın kaybolur. */
    private fun TestScope.countFinished(timer: SessionRestTimer): IntArray {
        val counter = IntArray(1)
        backgroundScope.launch(start = CoroutineStart.UNDISPATCHED) {
            timer.finished.collect { counter[0]++ }
        }
        return counter
    }

    @Test
    fun start_showsRemainingTime_andCountsDown() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)

        timer.start(90)
        assertEquals(90, timer.rest.value?.totalSeconds)
        assertEquals(90, timer.rest.value?.remainingSeconds)

        advance(fake, 1_000)
        assertEquals(89, timer.rest.value?.remainingSeconds)
    }

    @Test
    fun start_clampsSecondsToRange() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)

        timer.start(5)
        assertEquals(15, timer.rest.value?.totalSeconds)
    }

    @Test
    fun naturalFinish_vibratesOnce_emitsFinished_andClearsState() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)
        val finished = countFinished(timer)

        timer.start(90)
        advance(fake, 89_000)
        assertEquals(0, fake.vibrations)
        assertEquals(0, finished[0])

        advance(fake, 2_000)
        assertNull(timer.rest.value)
        assertEquals(1, fake.vibrations)
        assertEquals(1, finished[0])
    }

    @Test
    fun skip_stopsWithoutVibrationOrFinishEvent() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)
        val finished = countFinished(timer)

        timer.start(60)
        timer.skip()
        advance(fake, 120_000)

        assertNull(timer.rest.value)
        assertEquals(0, fake.vibrations)
        assertEquals(0, finished[0])
    }

    @Test
    fun adjust_extendsRunningTimer() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)

        timer.start(60)
        timer.adjust(30)
        assertEquals(90, timer.rest.value?.totalSeconds)
        assertEquals(90, timer.rest.value?.remainingSeconds)

        advance(fake, 60_000)
        assertEquals(30, timer.rest.value?.remainingSeconds)
        assertEquals(0, fake.vibrations)
    }

    @Test
    fun adjust_shortensRunningTimer() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)

        timer.start(90)
        advance(fake, 10_000)
        timer.adjust(-15)
        assertEquals(65, timer.rest.value?.remainingSeconds)
    }

    @Test
    fun adjust_toZero_finishesTimer() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)
        val finished = countFinished(timer)

        timer.start(60)
        timer.adjust(-60)
        runCurrent()

        assertNull(timer.rest.value)
        assertEquals(1, fake.vibrations)
        assertEquals(1, finished[0])
    }

    @Test
    fun adjust_withoutRunningTimer_doesNothing() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)

        timer.adjust(30)
        assertNull(timer.rest.value)
    }

    @Test
    fun start_replacesRunningTimer_oldOneDoesNotFinish() = runTest {
        val fake = Fake()
        val timer = createTimer(fake)
        val finished = countFinished(timer)

        timer.start(60)
        advance(fake, 10_000)
        timer.start(120)
        assertEquals(120, timer.rest.value?.totalSeconds)
        assertEquals(120, timer.rest.value?.remainingSeconds)

        // Eski sayacın bitiş zamanı (60 sn) geçti; yeni sayaç hâlâ çalışmalı.
        advance(fake, 61_000)
        assertEquals(59, timer.rest.value?.remainingSeconds)
        assertEquals(0, fake.vibrations)
        assertEquals(0, finished[0])
    }
}
