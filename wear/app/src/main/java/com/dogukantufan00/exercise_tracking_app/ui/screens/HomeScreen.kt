package com.dogukantufan00.exercise_tracking_app.ui.screens

import android.app.Activity
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
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
import androidx.wear.compose.material3.AlertDialog
import androidx.wear.compose.material3.Button
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
import com.dogukantufan00.exercise_tracking_app.domain.suggestedDay
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel
import com.dogukantufan00.exercise_tracking_app.ui.components.AccentCardButton
import com.dogukantufan00.exercise_tracking_app.ui.components.CardButton
import com.dogukantufan00.exercise_tracking_app.ui.components.RestIndicator
import com.dogukantufan00.exercise_tracking_app.ui.components.SetProgressRing
import com.dogukantufan00.exercise_tracking_app.ui.theme.WatchType
import com.dogukantufan00.exercise_tracking_app.ui.theme.upperTr
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
    var confirmFinish by remember { mutableStateOf(false) }
    val activity = LocalContext.current as? Activity

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
                        Text(
                            text = current.title.upperTr(),
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
                    CardButton(onClick = onOpenRestSettings) {
                        MutedLine(text = "Dinlenme süresi: ${formatDuration(restSeconds)}")
                    }
                }
                item {
                    CardButton(onClick = { confirmFinish = true }) {
                        Text(
                            text = "ANTRENMANI BİTİR",
                            style = WatchType.action,
                            color = MaterialTheme.colorScheme.primary,
                            textAlign = TextAlign.Center,
                            maxLines = 1,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        }
        AlertDialog(
            confirmFinish,
            onDismissRequest = { confirmFinish = false },
            confirmButton = {
                Button(
                    onClick = {
                        confirmFinish = false
                        // Antrenman bitti: olay kuyruğa yazılınca uygulama kapanır, saat kadrana döner.
                        viewModel.finishWorkout(onFinished = { activity?.finish() })
                    },
                ) {
                    Text("Bitir")
                }
            },
            dismissButton = {
                Button(onClick = { confirmFinish = false }) {
                    Text("Vazgeç")
                }
            },
            title = { Text("Antrenmanı bitir?") },
            text = { Text("Setler telefonda kalır.") },
        )
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
                Text(text = "ANTRENMAN", style = WatchType.header, maxLines = 1)
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
                TodayButton(day = today, onClick = { onStartDay(today.dayId) })
            }
        }
        if (others.isNotEmpty()) {
            item {
                ListHeader {
                    Text(
                        text = "Başka gün",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                    )
                }
            }
            items(others.size) { index ->
                val day = others[index]
                DayButton(day = day, onClick = { onStartDay(day.dayId) })
            }
        }
        item {
            // Program yoksa tek seçenek budur; o zaman ekranın dolu vurgu düğmesi olur.
            if (today == null && others.isEmpty()) {
                AccentCardButton(onClick = { onStartDay(null) }) {
                    Text(
                        text = "BOŞ ANTRENMAN",
                        style = WatchType.action,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            } else {
                CardButton(onClick = { onStartDay(null) }) {
                    MutedLine(text = "+ Boş antrenman")
                }
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

/** Bugünün günü: ekranın tek dolu vurgu düğmesi; "BUGÜN" etiketi, Oswald gün adı ve hareket sayısı. */
@Composable
private fun TodayButton(day: WatchProgramDay, onClick: () -> Unit) {
    AccentCardButton(onClick = onClick) {
        Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "BUGÜN",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onPrimary,
            )
            Text(
                text = day.name.upperTr(),
                style = WatchType.action,
                color = MaterialTheme.colorScheme.onPrimary,
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = formatExerciseCount(day.exercises.size),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onPrimary,
            )
        }
    }
}

/** Başka bir program günü: çerçeveli kart, solda Oswald ad, sağda hareket sayısı. */
@Composable
private fun DayButton(day: WatchProgramDay, onClick: () -> Unit) {
    CardButton(onClick = onClick) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = day.name,
                style = WatchType.cardTitle,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = formatExerciseCount(day.exercises.size),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 6.dp),
            )
        }
    }
}

/** Kart içinde ortalanmış soluk tek satır (ikincil eylemler). */
@Composable
private fun MutedLine(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textAlign = TextAlign.Center,
        maxLines = 1,
        modifier = Modifier.fillMaxWidth(),
    )
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
                text = (pending.dayName ?: "Boş antrenman").upperTr(),
                style = WatchType.header,
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
            CardButton(onClick = onCancel, modifier = Modifier.padding(horizontal = 28.dp)) {
                MutedLine(text = "İptal")
            }
        }
    }
}

/** Hareket listesi kartı: solda Oswald ad, sağda set halkası ("2/3", hedefe ulaşınca ✓). */
@Composable
private fun ExerciseButton(exercise: DisplayExercise, onClick: () -> Unit) {
    CardButton(onClick = onClick) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = exercise.name,
                style = WatchType.cardTitle,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            SetProgressRing(done = exercise.sets.size, target = exercise.target?.sets)
        }
    }
}
