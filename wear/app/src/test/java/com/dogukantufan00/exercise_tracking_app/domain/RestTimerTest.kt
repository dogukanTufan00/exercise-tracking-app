package com.dogukantufan00.exercise_tracking_app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RestTimerTest {

    @Test
    fun clampSeconds_limitsToRange() {
        assertEquals(15, RestTimer.clampSeconds(0))
        assertEquals(600, RestTimer.clampSeconds(9999))
        assertEquals(90, RestTimer.clampSeconds(90))
    }

    @Test
    fun stepSeconds_usesFifteenSecondSteps() {
        assertEquals(105, RestTimer.stepSeconds(90, 1))
        assertEquals(75, RestTimer.stepSeconds(90, -1))
    }

    @Test
    fun stepSeconds_staysInRange() {
        assertEquals(15, RestTimer.stepSeconds(15, -1))
        assertEquals(600, RestTimer.stepSeconds(600, 1))
    }

    @Test
    fun start_setsEndFromNow() {
        val countdown = RestTimer.start(90, nowMillis = 1_000L)
        assertEquals(90, countdown.totalSeconds)
        assertEquals(91_000L, countdown.endAtMillis)
    }

    @Test
    fun remainingMillis_neverNegative() {
        val countdown = RestTimer.start(30, nowMillis = 0L)
        assertEquals(30_000L, RestTimer.remainingMillis(countdown, 0L))
        assertEquals(0L, RestTimer.remainingMillis(countdown, 99_000L))
    }

    @Test
    fun isFinished_onlyWhenNoTimeLeft() {
        val countdown = RestTimer.start(30, nowMillis = 0L)
        assertFalse(RestTimer.isFinished(countdown, 29_999L))
        assertTrue(RestTimer.isFinished(countdown, 30_000L))
    }

    @Test
    fun progress_roundsRemainingSecondsUp() {
        val countdown = RestTimer.start(90, nowMillis = 0L)
        val progress = RestTimer.progress(countdown, nowMillis = 200L)
        assertEquals(90, progress.remainingSeconds)
        assertEquals(90, progress.totalSeconds)
    }

    @Test
    fun progress_fractionDropsFromOneToZero() {
        val countdown = RestTimer.start(60, nowMillis = 0L)
        assertEquals(1f, RestTimer.progress(countdown, 0L).remainingFraction, 0.0001f)
        assertEquals(0.5f, RestTimer.progress(countdown, 30_000L).remainingFraction, 0.0001f)
        assertEquals(0f, RestTimer.progress(countdown, 60_000L).remainingFraction, 0.0001f)
    }

    @Test
    fun progress_zeroRemainingAtEnd() {
        val countdown = RestTimer.start(60, nowMillis = 0L)
        assertEquals(0, RestTimer.progress(countdown, 70_000L).remainingSeconds)
    }

    @Test
    fun adjust_extendsEndAndTotalTogether() {
        val countdown = RestTimer.start(60, nowMillis = 0L)
        val extended = RestTimer.adjust(countdown, 15)
        assertEquals(75, extended.totalSeconds)
        assertEquals(75_000L, extended.endAtMillis)
    }

    @Test
    fun adjust_shortensAndCanFinish() {
        val countdown = RestTimer.start(30, nowMillis = 0L)
        val shortened = RestTimer.adjust(countdown, -15)
        assertEquals(15, shortened.totalSeconds)
        assertEquals(15_000L, shortened.endAtMillis)
        assertFalse(RestTimer.isFinished(shortened, 14_000L))
        assertTrue(RestTimer.isFinished(RestTimer.adjust(shortened, -15), 15_000L))
    }

    @Test
    fun adjust_totalNeverBelowOne() {
        val countdown = RestCountdown(totalSeconds = 5, endAtMillis = 5_000L)
        assertEquals(1, RestTimer.adjust(countdown, -15).totalSeconds)
    }
}
