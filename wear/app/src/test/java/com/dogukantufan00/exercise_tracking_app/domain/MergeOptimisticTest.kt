package com.dogukantufan00.exercise_tracking_app.domain

import com.dogukantufan00.exercise_tracking_app.data.AddSetEvent
import com.dogukantufan00.exercise_tracking_app.data.DeleteSetEvent
import com.dogukantufan00.exercise_tracking_app.data.WatchEvent
import com.dogukantufan00.exercise_tracking_app.data.WatchExercise
import com.dogukantufan00.exercise_tracking_app.data.WatchSet
import com.dogukantufan00.exercise_tracking_app.data.WatchSetValue
import com.dogukantufan00.exercise_tracking_app.data.WatchSnapshot
import com.dogukantufan00.exercise_tracking_app.data.WatchTarget
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MergeOptimisticTest {

    private val benchSets = listOf(
        WatchSet(id = 900, setNumber = 1, weightKg = 40.0, reps = 10),
        WatchSet(id = 901, setNumber = 2, weightKg = 40.0, reps = 9),
        WatchSet(id = 902, setNumber = 3, weightKg = 42.5, reps = 8),
    )

    private fun snapshot(
        workoutId: Long = 42,
        appliedEventIds: List<String> = emptyList(),
        sets: List<WatchSet> = benchSets,
    ) = WatchSnapshot(
        workoutId = workoutId,
        title = "Push A",
        startedAt = "2026-11-21T18:30:00.000",
        appliedEventIds = appliedEventIds,
        exercises = listOf(
            WatchExercise(
                workoutExerciseId = 101,
                name = "Bench Press",
                target = WatchTarget(sets = 4, reps = 10, weightKg = 40.0),
                sets = sets,
                draft = WatchSetValue(weightKg = 42.5, reps = 8),
                previous = listOf(WatchSetValue(weightKg = 37.5, reps = 10)),
            ),
            WatchExercise(
                workoutExerciseId = 102,
                name = "Row",
                target = null,
                sets = emptyList(),
                draft = WatchSetValue(weightKg = 30.0, reps = 12),
                previous = emptyList(),
            ),
        ),
    )

    private fun addSet(
        eventId: String = "e1",
        workoutId: Long = 42,
        workoutExerciseId: Long = 101,
        weightKg: Double = 45.0,
        reps: Int = 6,
    ) = AddSetEvent(
        eventId = eventId,
        workoutId = workoutId,
        createdAt = "2026-11-21T18:41:05.000",
        workoutExerciseId = workoutExerciseId,
        weightKg = weightKg,
        reps = reps,
    )

    private fun deleteSet(
        eventId: String = "d1",
        workoutId: Long = 42,
        setId: Long = 901,
    ) = DeleteSetEvent(
        eventId = eventId,
        workoutId = workoutId,
        createdAt = "2026-11-21T18:42:00.000",
        setId = setId,
    )

    @Test
    fun nullSnapshotGivesNull() {
        assertNull(mergeOptimistic(null, listOf(addSet())))
    }

    @Test
    fun withoutEventsResultMatchesSnapshot() {
        val result = mergeOptimistic(snapshot(), emptyList())!!

        assertEquals(42L, result.workoutId)
        assertEquals("Push A", result.title)
        assertFalse(result.hasPendingEvents)
        assertEquals(listOf(900L, 901L, 902L), result.exercises[0].sets.map { it.id })
        assertEquals(listOf(1, 2, 3), result.exercises[0].sets.map { it.setNumber })
        assertFalse(result.exercises[0].sets.any { it.isPending })
        assertEquals(WatchSetValue(42.5, 8), result.exercises[0].draft)
        assertEquals(WatchTarget(4, 10, 40.0), result.exercises[0].target)
        assertEquals(listOf(WatchSetValue(37.5, 10)), result.exercises[0].previous)
        assertNull(result.exercises[1].target)
    }

    @Test
    fun pendingSetIsAppendedAndDraftChanges() {
        val result = mergeOptimistic(snapshot(), listOf(addSet(weightKg = 45.0, reps = 6)))!!

        val sets = result.exercises[0].sets
        assertEquals(4, sets.size)
        val pending = sets.last()
        assertTrue(pending.isPending)
        assertNull(pending.id)
        assertEquals("e1", pending.pendingEventId)
        assertEquals(4, pending.setNumber)
        assertEquals(45.0, pending.weightKg, 0.0)
        assertEquals(6, pending.reps)
        assertEquals(WatchSetValue(45.0, 6), result.exercises[0].draft)
        assertTrue(result.hasPendingEvents)
    }

    @Test
    fun appliedEventIsIgnored() {
        val result = mergeOptimistic(snapshot(appliedEventIds = listOf("e1")), listOf(addSet(eventId = "e1")))!!

        assertEquals(3, result.exercises[0].sets.size)
        assertFalse(result.hasPendingEvents)
        assertEquals(WatchSetValue(42.5, 8), result.exercises[0].draft)
    }

    @Test
    fun eventOfAnotherWorkoutIsIgnored() {
        val result = mergeOptimistic(snapshot(), listOf(addSet(workoutId = 7)))!!

        assertEquals(3, result.exercises[0].sets.size)
        assertFalse(result.hasPendingEvents)
    }

    @Test
    fun addSetToUnknownExerciseIsIgnored() {
        val result = mergeOptimistic(snapshot(), listOf(addSet(workoutExerciseId = 999)))!!

        assertEquals(3, result.exercises[0].sets.size)
        assertEquals(0, result.exercises[1].sets.size)
        assertFalse(result.hasPendingEvents)
    }

    @Test
    fun invalidAddSetValuesAreIgnored() {
        val negative = mergeOptimistic(snapshot(), listOf(addSet(weightKg = -1.0)))!!
        val zeroReps = mergeOptimistic(snapshot(), listOf(addSet(reps = 0)))!!

        assertFalse(negative.hasPendingEvents)
        assertFalse(zeroReps.hasPendingEvents)
    }

    @Test
    fun deleteSetRemovesAndRenumbers() {
        val result = mergeOptimistic(snapshot(), listOf(deleteSet(setId = 901)))!!

        val sets = result.exercises[0].sets
        assertEquals(listOf(900L, 902L), sets.map { it.id })
        assertEquals(listOf(1, 2), sets.map { it.setNumber })
        assertTrue(result.hasPendingEvents)
    }

    @Test
    fun deleteUnknownSetIsIgnored() {
        val result = mergeOptimistic(snapshot(), listOf(deleteSet(setId = 12345)))!!

        assertEquals(listOf(900L, 901L, 902L), result.exercises[0].sets.map { it.id })
        assertFalse(result.hasPendingEvents)
    }

    @Test
    fun deleteAfterAddKeepsPendingSetAndNumbersInOrder() {
        val events: List<WatchEvent> = listOf(
            deleteSet(eventId = "d1", setId = 900),
            addSet(eventId = "e1", weightKg = 44.0, reps = 7),
        )

        val result = mergeOptimistic(snapshot(), events)!!

        val sets = result.exercises[0].sets
        assertEquals(listOf(901L, 902L, null), sets.map { it.id })
        assertEquals(listOf(1, 2, 3), sets.map { it.setNumber })
        assertEquals("e1", sets.last().pendingEventId)
    }
}
