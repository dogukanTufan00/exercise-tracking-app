package com.dogukantufan00.exercise_tracking_app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.ScalingLazyListState
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import kotlinx.coroutines.delay
import com.dogukantufan00.exercise_tracking_app.data.PendingStart
import com.dogukantufan00.exercise_tracking_app.data.WatchProgram
import com.dogukantufan00.exercise_tracking_app.data.WatchProgramDay
import com.dogukantufan00.exercise_tracking_app.domain.DisplayExercise
import com.dogukantufan00.exercise_tracking_app.domain.formatDuration
import com.dogukantufan00.exercise_tracking_app.domain.formatExerciseCount
import com.dogukantufan00.exercise_tracking_app.domain.formatSetProgress
import com.dogukantufan00.exercise_tracking_app.domain.suggestedDay
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel
import com.dogukantufan00.exercise_tracking_app.ui.components.RestIndicator
import java.time.LocalDate

/** Telefondan sonra başlatmanın "Telefonda uygulamayı aç" ipucuna döneceği süre (ms). */
private const val START_TIMEOUT_MILLIS = 5_000L

/**
 * Açılış ekranı. Etkin antrenman varsa hareket listesi; yoksa bekleyen başlatma varsa bekleme ekranı,
 * yoksa başlatma ekranı (bugünün programı, diğer günler, boş antrenman).
 */
@Composable
fun HomeScreen(
    viewModel: WatchWorkoutViewModel,
    onOpenExercise: (Long) -> Unit,
    onOpenRest: () -> Unit,
    onOpenRestSettings: () -> Unit,
) {
    val workout by viewModel.workout.collectAsStateWithLifecycle()
    val pending by viewModel.pendingStart.collectAsStateWithLifecycle()
    val program by viewModel.program.collectAsStateWithLifecycle()
    val reachable by viewModel.phoneReachable.collectAsStateWithLifecycle()
    val restSeconds by viewModel.restSeconds.collectAsStateWithLifecycle()
    val rest by viewModel.rest.collectAsStateWithLifecycle()
    val listState = rememberScalingLazyListState()

    val current = workout
    val waiting = pending
    if (current != null) {
        ScreenScaffold(scrollState = listState) { contentPadding ->
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
                rest?.let { progress ->
                    item { RestIndicator(rest = progress, onClick = onOpenRest) }
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
    } else if (waiting != null) {
        ScreenScaffold { contentPadding ->
            PendingStartContent(
                pending = waiting,
                reachable = reachable,
                contentPadding = contentPadding,
                onCancel = { viewModel.cancelPendingStart() },
            )
        }
    } else {
        ScreenScaffold(scrollState = listState) { contentPadding ->
            StartContent(
                listState = listState,
                contentPadding = contentPadding,
                program = program,
                reachable = reachable,
                onStartDay = { viewModel.startWorkout(it) },
            )
        }
    }
}

/** Başlatma ekranı: bugünün günü, diğer günler ve boş antrenman. */
@Composable
private fun StartContent(
    listState: ScalingLazyListState,
    contentPadding: PaddingValues,
    program: WatchProgram?,
    reachable: Boolean,
    onStartDay: (Long?) -> Unit,
) {
    val today = program?.let { suggestedDay(it, LocalDate.now().dayOfWeek) }
    val others = program?.days.orEmpty().filter { it.dayId != today?.dayId }

    ScalingLazyColumn(
        state = listState,
        contentPadding = contentPadding,
        modifier = Modifier.fillMaxSize(),
    ) {
        item {
            ListHeader {
                Text(text = "Antrenman başlat", maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        if (!reachable) {
            item {
                Text(
                    text = "Telefon bağlı değil",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        if (today != null) {
            item {
                DayButton(
                    day = today,
                    label = "Bugün: ${today.name}",
                    onClick = { onStartDay(today.dayId) },
                    filled = true,
                )
            }
        }
        if (others.isNotEmpty()) {
            item {
                ListHeader {
                    Text(text = "Başka gün", maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            items(others.size) { index ->
                val day = others[index]
                DayButton(
                    day = day,
                    label = day.name,
                    onClick = { onStartDay(day.dayId) },
                    filled = false,
                )
            }
        }
        item {
            Button(
                onClick = { onStartDay(null) },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.filledVariantButtonColors(),
            ) {
                Text(text = "Boş antrenman")
            }
        }
        if (program == null) {
            item {
                Text(
                    text = "Telefonda program oluşturabilirsin",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
                )
            }
        }
    }
}

/** Bir program günü düğmesi: ad ve hareket sayısı. */
@Composable
private fun DayButton(day: WatchProgramDay, label: String, onClick: () -> Unit, filled: Boolean) {
    Button(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = if (filled) ButtonDefaults.buttonColors() else ButtonDefaults.filledTonalButtonColors(),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(text = label, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                text = formatExerciseCount(day.exercises.size),
                style = MaterialTheme.typography.labelSmall,
                color = if (filled) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/**
 * Başlatma isteği gönderildi, telefon henüz uygulamadı. Telefon erişilemiyorsa ya da 5 sn geçtiyse
 * "Telefonda uygulamayı aç" gösterilir; İptal bekleyen isteği siler.
 */
@Composable
private fun PendingStartContent(
    pending: PendingStart,
    reachable: Boolean,
    contentPadding: PaddingValues,
    onCancel: () -> Unit,
) {
    var timedOut by remember(pending.eventId) { mutableStateOf(false) }
    LaunchedEffect(pending.eventId) {
        delay(START_TIMEOUT_MILLIS)
        timedOut = true
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(contentPadding),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = pending.dayName ?: "Boş antrenman",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onBackground,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = "Başlatılıyor…",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (!reachable || timedOut) {
                Text(
                    text = "Telefonda uygulamayı aç",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
            Button(
                onClick = onCancel,
                colors = ButtonDefaults.filledVariantButtonColors(),
            ) {
                Text(text = "İptal")
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
