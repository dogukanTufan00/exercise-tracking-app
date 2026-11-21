package com.dogukantufan00.exercise_tracking_app.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.navigation.NavType
import androidx.navigation.navArgument
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import com.dogukantufan00.exercise_tracking_app.ui.screens.ExerciseScreen
import com.dogukantufan00.exercise_tracking_app.ui.screens.HomeScreen
import com.dogukantufan00.exercise_tracking_app.ui.screens.RestScreen
import com.dogukantufan00.exercise_tracking_app.ui.screens.RestSettingsScreen
import kotlinx.coroutines.flow.Flow

/** Gezinme rotaları. Geri gitmek kaydırmayla yapılır (SwipeDismissableNavHost). */
object WatchRoutes {
    const val HOME = "home"
    const val EXERCISE = "exercise/{workoutExerciseId}"
    const val REST = "rest"
    const val REST_SETTINGS = "rest_settings"

    const val EXERCISE_ARG = "workoutExerciseId"

    fun exercise(workoutExerciseId: Long): String = "exercise/$workoutExerciseId"
}

/**
 * Saatin ekran yığını: ana ekran (antrenman yoksa başlatma) → hareket → dinlenme; ayrıca dinlenme süresi ayarı.
 * [launches] Tile/telefon açılış isteklerini verir (bkz. §15.8 madde 5); her istek bir kez işlenir.
 */
@Composable
fun WatchNavHost(viewModel: WatchWorkoutViewModel, launches: Flow<LaunchRequest>) {
    val navController = rememberSwipeDismissableNavController()

    LaunchedEffect(launches) {
        launches.collect { request ->
            when (request) {
                is LaunchRequest.StartDay -> if (viewModel.workout.value == null) {
                    viewModel.startWorkout(request.dayId)
                }
                LaunchRequest.StartEmpty -> if (viewModel.workout.value == null) {
                    viewModel.startWorkout(null)
                }
                LaunchRequest.OpenStart -> Unit
            }
            // Açılış isteklerinde her zaman ana ekrana dön: başlatma ekranı ya da hareket listesi orada.
            navController.popBackStack(WatchRoutes.HOME, inclusive = false)
        }
    }

    SwipeDismissableNavHost(
        navController = navController,
        startDestination = WatchRoutes.HOME,
    ) {
        composable(WatchRoutes.HOME) {
            HomeScreen(
                viewModel = viewModel,
                onOpenExercise = { id -> navController.navigate(WatchRoutes.exercise(id)) },
                onOpenRest = { navController.navigate(WatchRoutes.REST) },
                onOpenRestSettings = { navController.navigate(WatchRoutes.REST_SETTINGS) },
            )
        }
        composable(
            route = WatchRoutes.EXERCISE,
            arguments = listOf(navArgument(WatchRoutes.EXERCISE_ARG) { type = NavType.LongType }),
        ) { entry ->
            val workoutExerciseId = entry.arguments?.getLong(WatchRoutes.EXERCISE_ARG) ?: 0L
            ExerciseScreen(
                viewModel = viewModel,
                workoutExerciseId = workoutExerciseId,
                onSetAdded = { navController.navigate(WatchRoutes.REST) },
                onMissing = { navController.popBackStack(WatchRoutes.HOME, inclusive = false) },
                onOpenRest = { navController.navigate(WatchRoutes.REST) },
            )
        }
        composable(WatchRoutes.REST) {
            RestScreen(
                viewModel = viewModel,
                onDone = { navController.popBackStack() },
            )
        }
        composable(WatchRoutes.REST_SETTINGS) {
            RestSettingsScreen(viewModel = viewModel)
        }
    }
}
