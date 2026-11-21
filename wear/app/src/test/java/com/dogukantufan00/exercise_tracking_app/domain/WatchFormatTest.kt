package com.dogukantufan00.exercise_tracking_app.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class WatchFormatTest {

    @Test
    fun formatWeight_usesCommaForHalfKg() {
        assertEquals("37,5", formatWeight(37.5))
    }

    @Test
    fun formatWeight_dropsFractionForWholeKg() {
        assertEquals("40", formatWeight(40.0))
    }

    @Test
    fun formatWeight_zero() {
        assertEquals("0", formatWeight(0.0))
    }

    @Test
    fun formatSet_joinsWeightAndReps() {
        assertEquals("40 × 10", formatSet(40.0, 10))
    }

    @Test
    fun formatTarget_withWeight() {
        assertEquals("Hedef 3 × 10 · 40 kg", formatTarget(3, 10, 40.0))
    }

    @Test
    fun formatTarget_withoutWeight() {
        assertEquals("Hedef 3 × 10", formatTarget(3, 10, null))
    }

    @Test
    fun formatPrevious_prefixesGeçen() {
        assertEquals("Geçen: 37,5 × 10", formatPrevious(37.5, 10))
    }

    @Test
    fun formatSetProgress_withTarget() {
        assertEquals("2/3 set", formatSetProgress(2, 3))
    }

    @Test
    fun formatSetProgress_withoutTarget() {
        assertEquals("2 set", formatSetProgress(2, null))
    }

    @Test
    fun formatDuration_padsSeconds() {
        assertEquals("1:05", formatDuration(65))
    }

    @Test
    fun formatDuration_ninetySeconds() {
        assertEquals("1:30", formatDuration(90))
    }

    @Test
    fun formatDuration_tenMinutes() {
        assertEquals("10:00", formatDuration(600))
    }

    @Test
    fun formatDuration_negativeIsZero() {
        assertEquals("0:00", formatDuration(-5))
    }

    @Test
    fun stepWeight_addsTwoAndHalfPerStep() {
        assertEquals(42.5, stepWeight(40.0, 1), 0.0)
        assertEquals(35.0, stepWeight(37.5, -1), 0.0)
    }

    @Test
    fun stepWeight_neverBelowZero() {
        assertEquals(0.0, stepWeight(1.0, -3), 0.0)
    }

    @Test
    fun stepReps_addsOneAndNeverBelowOne() {
        assertEquals(11, stepReps(10, 1))
        assertEquals(1, stepReps(1, -1))
        assertEquals(1, stepReps(2, -5))
    }

    @Test
    fun formatExerciseCount_usesHareketSuffix() {
        assertEquals("5 hareket", formatExerciseCount(5))
        assertEquals("0 hareket", formatExerciseCount(0))
    }
}
