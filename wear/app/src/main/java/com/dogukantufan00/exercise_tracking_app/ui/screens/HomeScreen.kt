package com.dogukantufan00.exercise_tracking_app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import com.dogukantufan00.exercise_tracking_app.domain.DisplayExercise
import com.dogukantufan00.exercise_tracking_app.domain.formatDuration
import com.dogukantufan00.exercise_tracking_app.domain.formatSetProgress
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel

/**
 * Açılış ekranı. Etkin antrenman yoksa boş durum; varsa hareket listesi ve dinlenme süresi düğmesi.
 */
@Composable
fun HomeScreen(
    viewModel: WatchWorkoutViewModel,
    onOpenExercise: (Long) -> Unit,
    onOpenRestSettings: () -> Unit,
) {
    val workout by viewModel.workout.collectAsStateWithLifecycle()
    val reachable by viewModel.phoneReachable.collectAsStateWithLifecycle()
    val restSeconds by viewModel.restSeconds.collectAsStateWithLifecycle()
    val listState = rememberScalingLazyListState()

    ScreenScaffold(scrollState = listState) { contentPadding ->
        val current = workout
        if (current == null) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(contentPadding),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    text = "Telefonda bir antrenman aç",
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onBackground,
                )
                if (!reachable) {
                    Text(
                        text = "Telefon bağlı değil",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        } else {
            ScalingLazyColumn(
                state = listState,
                contentPadding = contentPadding,
                modifier = Modifier.fillMaxSize(),
            ) {
                item {
                    ListHeader {
                        Text(text = current.title, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    }
                }
                if (!reachable && current.hasPendingEvents) {
                    item {
                        Text(
                            text = "Bekliyor",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                items(current.exercises.size) { index ->
                    val exercise = current.exercises[index]
                    ExerciseButton(
                        exercise = exercise,
                        onClick = { onOpenExercise(exercise.workoutExerciseId) },
                    )
                }
                item {
                    Button(
                        onClick = onOpenRestSettings,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.filledVariantButtonColors(),
                    ) {
                        Text(text = "Dinlenme: ${formatDuration(restSeconds)}")
                    }
                }
            }
        }
    }
}

@Composable
private fun ExerciseButton(exercise: DisplayExercise, onClick: () -> Unit) {
    val done = exercise.sets.size
    val target = exercise.target?.sets
    val reached = target != null && done >= target
    val progress = (if (reached) "✓ " else "") + formatSetProgress(done, target)

    Button(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.filledTonalButtonColors(),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(text = exercise.name, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                text = progress,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
