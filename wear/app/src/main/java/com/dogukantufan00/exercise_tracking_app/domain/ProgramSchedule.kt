package com.dogukantufan00.exercise_tracking_app.domain

import com.dogukantufan00.exercise_tracking_app.data.WatchProgram
import com.dogukantufan00.exercise_tracking_app.data.WatchProgramDay
import java.time.DayOfWeek

/**
 * Bugünün önerilen program günü: telefondaki `suggestedDay` ile aynı kural (lib/domain/program_schedule.dart):
 * weekday'i [today] olan ilk gün; yoksa null. [today].value: 1 = Pazartesi … 7 = Pazar. Saf Kotlin.
 */
fun suggestedDay(program: WatchProgram, today: DayOfWeek): WatchProgramDay? {
    TODO("Ajan BC uygular")
}
