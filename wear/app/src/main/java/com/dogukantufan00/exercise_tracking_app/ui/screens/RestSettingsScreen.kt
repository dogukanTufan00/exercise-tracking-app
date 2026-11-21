package com.dogukantufan00.exercise_tracking_app.ui.screens

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import com.dogukantufan00.exercise_tracking_app.domain.formatDuration
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel
import com.dogukantufan00.exercise_tracking_app.ui.components.StepperField
import com.dogukantufan00.exercise_tracking_app.ui.theme.WatchType

/** Varsayılan dinlenme süresi ayarı: −/+ ya da döner çerçeve ile 15 sn adımlarla (15 sn – 10 dk). */
@Composable
fun RestSettingsScreen(viewModel: WatchWorkoutViewModel) {
    val restSeconds by viewModel.restSeconds.collectAsStateWithLifecycle()
    val listState = rememberScalingLazyListState()

    ScreenScaffold(scrollState = listState) { contentPadding ->
        ScalingLazyColumn(
            state = listState,
            contentPadding = contentPadding,
            modifier = Modifier,
        ) {
            item {
                ListHeader {
                    Text(
                        text = "DİNLENME SÜRESİ",
                        style = WatchType.header,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            item {
                StepperField(
                    label = "15 sn adımlarla",
                    valueText = formatDuration(restSeconds),
                    focused = true,
                    onFocus = {},
                    onStep = { viewModel.stepRestSetting(it) },
                )
            }
        }
    }
}
