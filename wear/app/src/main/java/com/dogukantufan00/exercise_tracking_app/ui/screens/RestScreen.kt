package com.dogukantufan00.exercise_tracking_app.ui.screens

import android.app.Activity
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import com.dogukantufan00.exercise_tracking_app.domain.formatDuration
import com.dogukantufan00.exercise_tracking_app.hasAllPermissions
import com.dogukantufan00.exercise_tracking_app.session.SessionController
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel
import com.dogukantufan00.exercise_tracking_app.ui.theme.WatchType

/**
 * Dinlenme sayacı: tam ve kalın dairesel ilerleme, büyük Oswald kalan süre, "Sıradaki: Bench Press 3. set" ve
 * halkanın içinde üç yuvarlak düğme (−15 sn, ortada dolu "Atla" », +15 sn). Sayaç arka planda sürer (§15.8):
 * bu ekrandan kaydırarak çıkmak sayacı durdurmaz; süre bitince kontrolcü titretir ve bu ekran geri döner.
 *
 * Ölçüler SM-L340'a göre (ekran ~206 dp, halkanın içi ~90 dp yarıçap): yan düğmeler 42 dp görünür daire
 * (dokunma alanı 48 dp), merkezden en uzak noktaları ~87 dp, yani halkaya değmez.
 */
@Composable
fun RestScreen(
    viewModel: WatchWorkoutViewModel,
    onDone: () -> Unit,
) {
    val context = LocalContext.current
    val rest by viewModel.rest.collectAsStateWithLifecycle()
    val workout by viewModel.workout.collectAsStateWithLifecycle()
    val lastExerciseId by viewModel.lastExerciseId.collectAsStateWithLifecycle()
    val next = workout?.exercises?.firstOrNull { it.workoutExerciseId == lastExerciseId }

    // Antrenman servisi (ekran kapalıyken de çalışan sayaç) yoksa sayaç ekran açıkken çalışır.
    KeepScreenOn(enabled = rest != null && !hasAllPermissions(context, SessionController.requiredPermissions()))

    // Ekran yalnızca bir kez kapanır: süre bitişi, "Atla" ya da telefondan atlanma aynı anda gelse de iki kez geri gitmez.
    var left by remember { mutableStateOf(false) }
    fun leave() {
        if (!left) {
            left = true
            onDone()
        }
    }
    // Sayaç ekran açıkken kalkarsa (telefonda atlandı ya da bitti) geri dön. İlk karede sayaç henüz
    // gelmemiş olabilir; bu yüzden yalnızca bir kez çalıştığı görüldükten sonra dönülür.
    var sawRest by remember { mutableStateOf(false) }
    val running = rest != null
    LaunchedEffect(running) {
        if (running) sawRest = true else if (sawRest) leave()
    }

    LaunchedEffect(Unit) {
        viewModel.restFinished.collect { leave() }
    }

    // Kaydırılabilir liste yerine sabit düzen: yuvarlak ekranda ölçeklenip kaymasın.
    ScreenScaffold {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            CircularProgressIndicator(
                progress = { rest?.remainingFraction ?: 0f },
                modifier = Modifier.fillMaxSize().padding(3.dp),
                strokeWidth = 10.dp,
            )
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = formatDuration(rest?.remainingSeconds ?: 0),
                    style = WatchType.timer,
                    color = MaterialTheme.colorScheme.onBackground,
                )
                Text(
                    text = next?.let { "Sıradaki: ${it.name} ${it.sets.size + 1}. set" } ?: "",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.widthIn(max = 150.dp).height(16.dp),
                )
                Spacer(Modifier.height(4.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    RoundRestButton(
                        text = "−15",
                        visualSize = 42.dp,
                        fill = MaterialTheme.colorScheme.surfaceContainer,
                        content = MaterialTheme.colorScheme.onSurface,
                        onClick = { viewModel.adjustRest(-15) },
                    )
                    RoundRestButton(
                        text = "»",
                        visualSize = 52.dp,
                        fill = MaterialTheme.colorScheme.primary,
                        content = MaterialTheme.colorScheme.onPrimary,
                        onClick = {
                            viewModel.skipRest()
                            leave()
                        },
                    )
                    RoundRestButton(
                        text = "+15",
                        visualSize = 42.dp,
                        fill = MaterialTheme.colorScheme.surfaceContainer,
                        content = MaterialTheme.colorScheme.onSurface,
                        onClick = { viewModel.adjustRest(15) },
                    )
                }
            }
        }
    }
}

/** Dolu yuvarlak düğme: [visualSize] görünen daire, dokunma alanı en az 48 dp. */
@Composable
private fun RoundRestButton(text: String, visualSize: Dp, fill: Color, content: Color, onClick: () -> Unit) {
    val touch = if (visualSize > 48.dp) visualSize else 48.dp
    Box(
        modifier = Modifier
            .size(touch)
            .clip(CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier.size(visualSize).background(fill, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = text,
                style = if (text == "»") WatchType.number else WatchType.smallNumber,
                color = content,
            )
        }
    }
}

/** [enabled] iken ekran açık tutulur; kapanınca bayrak kaldırılır. */
@Composable
private fun KeepScreenOn(enabled: Boolean) {
    val activity = LocalContext.current as? Activity
    DisposableEffect(activity, enabled) {
        if (enabled) activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose {
            if (enabled) activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
