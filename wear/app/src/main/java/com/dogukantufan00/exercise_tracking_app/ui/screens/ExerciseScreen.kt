package com.dogukantufan00.exercise_tracking_app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.AlertDialog
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.EdgeButton
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import com.dogukantufan00.exercise_tracking_app.data.WatchSetValue
import com.dogukantufan00.exercise_tracking_app.domain.DisplayExercise
import com.dogukantufan00.exercise_tracking_app.domain.DisplaySet
import com.dogukantufan00.exercise_tracking_app.domain.formatPrevious
import com.dogukantufan00.exercise_tracking_app.domain.formatSet
import com.dogukantufan00.exercise_tracking_app.domain.formatTarget
import com.dogukantufan00.exercise_tracking_app.domain.formatWeight
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel
import com.dogukantufan00.exercise_tracking_app.ui.components.StepperField

/** Ağırlık ve tekrar alanlarından hangisinin döner çerçeveyle değiştiği. */
private enum class InputField { WEIGHT, REPS }

/**
 * Hareket ekranı: hedef, geçen sefer, ağırlık/tekrar girişi, "Set tamam" ve bu hareketin setleri.
 * Hareket telefonda kaybolursa (antrenman silindi vb.) [onMissing] çağrılır.
 */
@Composable
fun ExerciseScreen(
    viewModel: WatchWorkoutViewModel,
    workoutExerciseId: Long,
    onSetAdded: () -> Unit,
    onMissing: () -> Unit,
) {
    val workout by viewModel.workout.collectAsStateWithLifecycle()
    val edits by viewModel.inputEdits.collectAsStateWithLifecycle()
    val exercise = workout?.exercises?.firstOrNull { it.workoutExerciseId == workoutExerciseId }

    if (exercise == null) {
        LaunchedEffect(Unit) { onMissing() }
    } else {
        ExerciseContent(
            viewModel = viewModel,
            exercise = exercise,
            input = edits[exercise.workoutExerciseId] ?: exercise.draft,
            onSetAdded = onSetAdded,
        )
    }
}

@Composable
private fun ExerciseContent(
    viewModel: WatchWorkoutViewModel,
    exercise: DisplayExercise,
    input: WatchSetValue,
    onSetAdded: () -> Unit,
) {
    var focused by remember { mutableStateOf(InputField.WEIGHT) }
    var pendingDeleteId by remember { mutableStateOf<Long?>(null) }
    val listState = rememberScalingLazyListState()
    val exerciseId = exercise.workoutExerciseId

    ScreenScaffold(
        scrollState = listState,
        edgeButton = {
            EdgeButton(
                onClick = {
                    viewModel.addSet(exerciseId)
                    onSetAdded()
                },
            ) {
                Text("Set tamam")
            }
        },
    ) { contentPadding ->
        ScalingLazyColumn(
            state = listState,
            contentPadding = contentPadding,
        ) {
            item {
                ListHeader {
                    Text(text = exercise.name, maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
            }
            exercise.target?.let { target ->
                item {
                    Text(
                        text = formatTarget(target.sets, target.reps, target.weightKg),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            exercise.previous.firstOrNull()?.let { previous ->
                item {
                    Text(
                        text = formatPrevious(previous.weightKg, previous.reps),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            item {
                StepperField(
                    label = "Ağırlık (kg)",
                    valueText = formatWeight(input.weightKg),
                    focused = focused == InputField.WEIGHT,
                    onFocus = { focused = InputField.WEIGHT },
                    onStep = { viewModel.adjustWeight(exerciseId, it) },
                )
            }
            item {
                StepperField(
                    label = "Tekrar",
                    valueText = input.reps.toString(),
                    focused = focused == InputField.REPS,
                    onFocus = { focused = InputField.REPS },
                    onStep = { viewModel.adjustReps(exerciseId, it) },
                )
            }
            items(exercise.sets.size) { index ->
                val set = exercise.sets[index]
                SetRow(
                    set = set,
                    onLongPress = { pendingDeleteId = set.id },
                )
            }
        }
    }

    AlertDialog(
        pendingDeleteId != null,
        onDismissRequest = { pendingDeleteId = null },
        confirmButton = {
            Button(
                onClick = {
                    pendingDeleteId?.let { viewModel.deleteSet(it) }
                    pendingDeleteId = null
                },
            ) {
                Text("Sil")
            }
        },
        dismissButton = {
            Button(onClick = { pendingDeleteId = null }) {
                Text("Vazgeç")
            }
        },
        title = { Text("Seti sil?") },
    )
}

/** Bir set satırı. Onaylı set uzun basınca silinebilir; bekleyen set soluk gösterilir. */
@Composable
private fun SetRow(set: DisplaySet, onLongPress: () -> Unit) {
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(24.dp))
            .combinedClickable(
                onClick = {},
                onLongClick = { if (!set.isPending) onLongPress() },
            )
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "${set.setNumber}. ${formatSet(set.weightKg, set.reps)}",
                style = MaterialTheme.typography.bodyMedium,
                color = if (set.isPending) muted else MaterialTheme.colorScheme.onBackground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (set.isPending) {
                Text(
                    text = "  bekliyor",
                    style = MaterialTheme.typography.labelSmall,
                    color = muted,
                )
            }
        }
    }
}
