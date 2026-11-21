package com.dogukantufan00.exercise_tracking_app.ui.screens

import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
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
import androidx.wear.compose.material3.TimeText
import com.dogukantufan00.exercise_tracking_app.data.WatchSetValue
import com.dogukantufan00.exercise_tracking_app.domain.DisplayExercise
import com.dogukantufan00.exercise_tracking_app.domain.DisplaySet
import com.dogukantufan00.exercise_tracking_app.domain.formatPrevious
import com.dogukantufan00.exercise_tracking_app.domain.formatSet
import com.dogukantufan00.exercise_tracking_app.domain.formatTarget
import com.dogukantufan00.exercise_tracking_app.domain.formatWeight
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel
import com.dogukantufan00.exercise_tracking_app.ui.components.RestIndicator
import com.dogukantufan00.exercise_tracking_app.ui.components.CardShape
import com.dogukantufan00.exercise_tracking_app.ui.components.SetField
import com.dogukantufan00.exercise_tracking_app.ui.components.SetInput
import com.dogukantufan00.exercise_tracking_app.ui.theme.WatchType
import com.dogukantufan00.exercise_tracking_app.ui.theme.upperTr

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
    onOpenRest: () -> Unit = {},
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
            onOpenRest = onOpenRest,
        )
    }
}

@Composable
private fun ExerciseContent(
    viewModel: WatchWorkoutViewModel,
    exercise: DisplayExercise,
    input: WatchSetValue,
    onSetAdded: () -> Unit,
    onOpenRest: () -> Unit,
) {
    var focused by remember { mutableStateOf(SetField.WEIGHT) }
    var pendingDeleteId by remember { mutableStateOf<Long?>(null) }
    val listState = rememberScalingLazyListState()
    val exerciseId = exercise.workoutExerciseId
    val rest by viewModel.rest.collectAsStateWithLifecycle()

    ScreenScaffold(
        scrollState = listState,
        timeText = { TimeText() },
        edgeButton = {
            EdgeButton(
                onClick = {
                    viewModel.addSet(exerciseId)
                    onSetAdded()
                },
            ) {
                Text("SET TAMAM", style = WatchType.action)
            }
        },
    ) { contentPadding ->
        ScalingLazyColumn(
            state = listState,
            contentPadding = contentPadding,
        ) {
            item {
                ListHeader {
                    Text(
                        text = exercise.name.upperTr(),
                        style = WatchType.header,
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            rest?.let { progress ->
                item { RestIndicator(rest = progress, onClick = onOpenRest) }
            }
            item {
                SetInput(
                    weightText = formatWeight(input.weightKg),
                    repsText = input.reps.toString(),
                    focused = focused,
                    onFocus = { focused = it },
                    doneSets = exercise.sets.size,
                    targetSets = exercise.target?.sets,
                    onStep = { field, steps ->
                        when (field) {
                            SetField.WEIGHT -> viewModel.adjustWeight(exerciseId, steps)
                            SetField.REPS -> viewModel.adjustReps(exerciseId, steps)
                        }
                    },
                )
            }
            val hints = listOfNotNull(
                exercise.target?.let { formatTarget(it.sets, it.reps, it.weightKg) },
                exercise.previous.firstOrNull()?.let { formatPrevious(it.weightKg, it.reps) },
            )
            if (hints.isNotEmpty()) {
                item {
                    Text(
                        text = hints.joinToString("\n"),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
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

/** Bir set satırı: çerçeveli kart, solda set no, ortada "60 × 8". Onaylı set uzun basınca silinebilir; bekleyen set soluk. */
@Composable
private fun SetRow(set: DisplaySet, onLongPress: () -> Unit) {
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .clip(CardShape)
            .border(1.dp, MaterialTheme.colorScheme.outline, CardShape)
            .combinedClickable(
                onClick = {},
                onLongClick = { if (!set.isPending) onLongPress() },
            )
            .padding(horizontal = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "${set.setNumber}",
            style = WatchType.smallNumber,
            color = muted,
            modifier = Modifier.align(Alignment.CenterStart),
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = formatSet(set.weightKg, set.reps),
                style = WatchType.number,
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
