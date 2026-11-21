package com.dogukantufan00.exercise_tracking_app.ui.preview

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import com.dogukantufan00.exercise_tracking_app.data.PendingStart
import com.dogukantufan00.exercise_tracking_app.data.RestSettingsStore
import com.dogukantufan00.exercise_tracking_app.data.WatchProgram
import com.dogukantufan00.exercise_tracking_app.data.WatchSetValue
import com.dogukantufan00.exercise_tracking_app.data.WatchTarget
import com.dogukantufan00.exercise_tracking_app.data.WorkoutSyncRepository
import com.dogukantufan00.exercise_tracking_app.domain.DisplayExercise
import com.dogukantufan00.exercise_tracking_app.domain.DisplaySet
import com.dogukantufan00.exercise_tracking_app.domain.DisplayWorkout
import com.dogukantufan00.exercise_tracking_app.domain.RestProgress
import com.dogukantufan00.exercise_tracking_app.domain.WatchThemeId
import com.dogukantufan00.exercise_tracking_app.session.RestTimerController
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel
import com.dogukantufan00.exercise_tracking_app.ui.screens.ExerciseScreen
import com.dogukantufan00.exercise_tracking_app.ui.screens.HomeScreen
import com.dogukantufan00.exercise_tracking_app.ui.screens.RestScreen
import com.dogukantufan00.exercise_tracking_app.ui.theme.WatchTheme
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

/** Önizlemeler için sayaç: hiçbir şey yapmaz (gerçek sayaç uygulama sınıfındadır). */
private class PreviewRestTimer : RestTimerController {
    override val rest: StateFlow<RestProgress?> = MutableStateFlow(null)
    override val finished: SharedFlow<Unit> = MutableSharedFlow()
    override fun start(totalSeconds: Int) = Unit
    override fun adjust(deltaSeconds: Int) = Unit
    override fun skip() = Unit
}

/** Önizlemeler için sahte repository: sabit bir antrenman ve erişilebilirlik durumu. Yazmalar yalnızca yoksayılır. */
class PreviewWorkoutSyncRepository(
    workout: DisplayWorkout?,
    reachable: Boolean = true,
) : WorkoutSyncRepository {
    override val workout: StateFlow<DisplayWorkout?> = MutableStateFlow(workout)
    override val phoneReachable: StateFlow<Boolean> = MutableStateFlow(reachable)

    override val program: StateFlow<WatchProgram?> = MutableStateFlow(null)
    override val pendingStart: StateFlow<PendingStart?> = MutableStateFlow(null)

    override suspend fun addSet(workoutExerciseId: Long, weightKg: Double, reps: Int) = Unit

    override suspend fun deleteSet(setId: Long) = Unit

    override suspend fun startWorkout(programDayId: Long?) = Unit

    override suspend fun finishWorkout() = Unit

    override suspend fun cancelPendingStart() = Unit
}

private val previewWorkout = DisplayWorkout(
    workoutId = 1L,
    title = "Push A",
    hasPendingEvents = true,
    exercises = listOf(
        DisplayExercise(
            workoutExerciseId = 101L,
            name = "Bench Press",
            target = WatchTarget(sets = 3, reps = 10, weightKg = 40.0),
            sets = listOf(
                DisplaySet(id = 900L, pendingEventId = null, setNumber = 1, weightKg = 40.0, reps = 10),
                DisplaySet(id = null, pendingEventId = "e1", setNumber = 2, weightKg = 40.0, reps = 9),
            ),
            draft = WatchSetValue(weightKg = 40.0, reps = 9),
            previous = listOf(WatchSetValue(weightKg = 37.5, reps = 10)),
        ),
        DisplayExercise(
            workoutExerciseId = 102L,
            name = "Lateral Raise",
            target = null,
            sets = emptyList(),
            draft = WatchSetValue(weightKg = 8.0, reps = 12),
            previous = emptyList(),
        ),
    ),
)

@Composable
private fun rememberPreviewViewModel(workout: DisplayWorkout?, reachable: Boolean = true): WatchWorkoutViewModel {
    val context = LocalContext.current
    return remember {
        WatchWorkoutViewModel(
            repository = PreviewWorkoutSyncRepository(workout, reachable),
            restSettings = RestSettingsStore.create(context),
            restTimer = PreviewRestTimer(),
        )
    }
}

@Preview(device = "spec:shape=Round,width=192,height=192,unit=dp,dpi=320", showSystemUi = true)
@Composable
private fun EmptyHomePreview() {
    WatchTheme(WatchThemeId.DarkOrange) {
        HomeScreen(
            viewModel = rememberPreviewViewModel(workout = null, reachable = false),
            onOpenExercise = {},
            onOpenRest = {},
            onOpenRestSettings = {},
        )
    }
}

@Preview(device = "spec:shape=Round,width=192,height=192,unit=dp,dpi=320", showSystemUi = true)
@Composable
private fun ExerciseListPreview() {
    WatchTheme(WatchThemeId.DarkOrange) {
        HomeScreen(
            viewModel = rememberPreviewViewModel(workout = previewWorkout, reachable = false),
            onOpenExercise = {},
            onOpenRest = {},
            onOpenRestSettings = {},
        )
    }
}

@Preview(device = "spec:shape=Round,width=192,height=192,unit=dp,dpi=320", showSystemUi = true)
@Composable
private fun ExercisePreview() {
    WatchTheme(WatchThemeId.DarkOrange) {
        ExerciseScreen(
            viewModel = rememberPreviewViewModel(workout = previewWorkout),
            workoutExerciseId = 101L,
            onSetAdded = {},
            onMissing = {},
        )
    }
}

@Preview(device = "spec:shape=Round,width=192,height=192,unit=dp,dpi=320", showSystemUi = true)
@Composable
private fun RestPreview() {
    WatchTheme(WatchThemeId.DarkOrange) {
        RestScreen(
            viewModel = rememberPreviewViewModel(workout = previewWorkout),
            onDone = {},
        )
    }
}
