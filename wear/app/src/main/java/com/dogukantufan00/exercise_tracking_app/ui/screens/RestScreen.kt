package com.dogukantufan00.exercise_tracking_app.ui.screens

import android.app.Activity
import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.WindowManager
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import com.dogukantufan00.exercise_tracking_app.domain.formatDuration
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel

/** Bitişte titreşim deseni (ms): kısa, kısa, uzun. */
private val FINISH_PATTERN_MS = longArrayOf(0L, 120L, 100L, 120L, 100L, 400L)

/** Dinlenme sayacı: dairesel ilerleme, kalan süre, ±15 sn ve "Atla". Bitince titreşir ve geri döner. */
@Composable
fun RestScreen(
    viewModel: WatchWorkoutViewModel,
    onDone: () -> Unit,
) {
    val context = LocalContext.current
    val rest by viewModel.rest.collectAsStateWithLifecycle()
    val listState = rememberScalingLazyListState()

    KeepScreenOn()

    LaunchedEffect(Unit) {
        viewModel.restFinished.collect {
            vibrateFinished(context)
            onDone()
        }
    }

    // Ekrandan çıkmak (kaydırarak geri) sayacı durdurur.
    DisposableEffect(Unit) {
        onDispose { viewModel.skipRest() }
    }

    ScreenScaffold(scrollState = listState) { contentPadding ->
        ScalingLazyColumn(
            state = listState,
            contentPadding = contentPadding,
        ) {
            item {
                Box(
                    modifier = Modifier.size(150.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(
                        progress = { rest?.remainingFraction ?: 0f },
                        modifier = Modifier.size(150.dp),
                    )
                    Text(
                        text = formatDuration(rest?.remainingSeconds ?: 0),
                        style = MaterialTheme.typography.numeralLarge,
                        color = MaterialTheme.colorScheme.onBackground,
                    )
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { viewModel.adjustRest(-15) }) {
                        Text("−15 sn")
                    }
                    Button(onClick = { viewModel.adjustRest(15) }) {
                        Text("+15 sn")
                    }
                }
            }
            item {
                Button(
                    onClick = {
                        viewModel.skipRest()
                        onDone()
                    },
                    colors = ButtonDefaults.filledTonalButtonColors(),
                ) {
                    Text("Atla")
                }
            }
        }
    }
}

/** Sayaç çalışırken ekran açık kalır; bu ekrandan çıkınca bayrak kaldırılır. */
@Composable
private fun KeepScreenOn() {
    val activity = LocalContext.current as? Activity
    DisposableEffect(activity) {
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose {
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}

/** Dinlenme bitince titreşim. Android 12+ VibratorManager, daha eski sürümlerde Vibrator kullanılır. */
private fun vibrateFinished(context: Context) {
    val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        context.getSystemService(VibratorManager::class.java)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Vibrator::class.java)
    }
    vibrator?.vibrate(VibrationEffect.createWaveform(FINISH_PATTERN_MS, -1))
}
