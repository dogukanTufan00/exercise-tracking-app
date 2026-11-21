package com.dogukantufan00.exercise_tracking_app.ui.screens

import android.app.Activity
import android.view.WindowManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.CompactButton
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import com.dogukantufan00.exercise_tracking_app.domain.formatDuration
import com.dogukantufan00.exercise_tracking_app.hasAllPermissions
import com.dogukantufan00.exercise_tracking_app.session.SessionController
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel

/**
 * Dinlenme sayacı: dairesel ilerleme, kalan süre, ±15 sn ve "Atla". Sayaç arka planda sürer (§15.8): bu ekrandan
 * kaydırarak çıkmak sayacı durdurmaz; süre bitince kontrolcü titretir ve bu ekran geri döner.
 */
@Composable
fun RestScreen(
    viewModel: WatchWorkoutViewModel,
    onDone: () -> Unit,
) {
    val context = LocalContext.current
    val rest by viewModel.rest.collectAsStateWithLifecycle()

    // Antrenman servisi (ekran kapalıyken de çalışan sayaç) yoksa sayaç ekran açıkken çalışır.
    KeepScreenOn(enabled = rest != null && !hasAllPermissions(context, SessionController.requiredPermissions()))

    LaunchedEffect(Unit) {
        viewModel.restFinished.collect { onDone() }
    }

    // Kaydırılabilir liste yerine sabit düzen: yuvarlak ekranda ölçeklenip kaymasın.
    ScreenScaffold {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            CircularProgressIndicator(
                progress = { rest?.remainingFraction ?: 0f },
                modifier = Modifier.fillMaxSize().padding(4.dp),
            )
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = formatDuration(rest?.remainingSeconds ?: 0),
                    style = MaterialTheme.typography.numeralMedium,
                    color = MaterialTheme.colorScheme.onBackground,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    CompactButton(onClick = { viewModel.adjustRest(-15) }) {
                        Text("−15 sn")
                    }
                    CompactButton(onClick = { viewModel.adjustRest(15) }) {
                        Text("+15 sn")
                    }
                }
                CompactButton(
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
