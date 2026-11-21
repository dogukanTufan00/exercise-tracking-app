package com.dogukantufan00.exercise_tracking_app.domain

import com.dogukantufan00.exercise_tracking_app.data.WatchProgram
import com.dogukantufan00.exercise_tracking_app.data.WatchProgramDay
import java.time.DayOfWeek
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ProgramScheduleTest {

    private val monday = WatchProgramDay(dayId = 11, name = "Push A", weekday = 1, exercises = listOf("Bench Press"))
    private val wednesday = WatchProgramDay(dayId = 12, name = "Pull A", weekday = 3, exercises = listOf("Row"))
    private val undated = WatchProgramDay(dayId = 13, name = "Serbest", weekday = null, exercises = emptyList())

    private fun program(vararg days: WatchProgramDay) =
        WatchProgram(programId = 3, name = "PPL", days = days.toList())

    @Test
    fun returnsDayPlannedForToday() {
        assertEquals(monday, suggestedDay(program(monday, wednesday), DayOfWeek.MONDAY))
    }

    @Test
    fun nullWhenNoDayIsPlannedForToday() {
        assertNull(suggestedDay(program(monday, wednesday), DayOfWeek.FRIDAY))
    }

    @Test
    fun undatedDaysAreNeverSuggested() {
        assertNull(suggestedDay(program(undated), DayOfWeek.MONDAY))
    }

    @Test
    fun firstMatchingDayWins() {
        val secondMonday = monday.copy(dayId = 14, name = "Push B")

        assertEquals(monday, suggestedDay(program(monday, secondMonday), DayOfWeek.MONDAY))
    }

    @Test
    fun sundayMatchesWeekdaySeven() {
        val sunday = WatchProgramDay(dayId = 15, name = "Dinlenme", weekday = 7, exercises = emptyList())

        assertEquals(sunday, suggestedDay(program(monday, sunday), DayOfWeek.SUNDAY))
    }

    @Test
    fun emptyProgramGivesNull() {
        assertNull(suggestedDay(program(), DayOfWeek.MONDAY))
    }
}
