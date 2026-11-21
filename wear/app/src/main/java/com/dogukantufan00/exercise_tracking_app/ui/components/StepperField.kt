package com.dogukantufan00.exercise_tracking_app.ui.components

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.Text
import com.dogukantufan00.exercise_tracking_app.ui.theme.WatchType

/** Döner çerçevenin bir adım için gerekli birikimi (piksel). */
internal const val ROTARY_PIXELS_PER_STEP = 40f

/**
 * Etiketli değer alanı: solda −, ortada değer, sağda +. Odaktaki alan döner çerçeve/taçla değişir.
 *
 * [onStep] adım sayısını alır (−/+ düğmesi ±1, döner çerçeve birikime göre). Alana dokunmak [onFocus] çağırır.
 * Odaktaki alan vurgu çerçevesiyle çizilir; düğmeye basınca odak tekrar bu alana döner ki döner çerçeve çalışsın.
 */
@Composable
fun StepperField(
    label: String,
    valueText: String,
    focused: Boolean,
    onFocus: () -> Unit,
    onStep: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val focusRequester = remember { FocusRequester() }
    var pendingPixels by remember { mutableFloatStateOf(0f) }

    LaunchedEffect(focused) {
        if (focused) focusRequester.requestFocus()
    }

    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            RoundStepButton(
                text = "−",
                onClick = {
                    onFocus()
                    onStep(-1)
                    focusRequester.requestFocus()
                },
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 6.dp)
                    .heightIn(min = 52.dp)
                    .clip(CardShape)
                    .border(
                        width = if (focused) 1.5.dp else 1.dp,
                        color = if (focused) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
                        shape = CardShape,
                    )
                    .focusRequester(focusRequester)
                    .onFocusChanged { if (it.isFocused) onFocus() }
                    .focusable()
                    .clickable(onClick = onFocus)
                    .onRotaryScrollEvent { event ->
                        pendingPixels += event.verticalScrollPixels
                        val steps = (pendingPixels / ROTARY_PIXELS_PER_STEP).toInt()
                        if (steps != 0) {
                            pendingPixels -= steps * ROTARY_PIXELS_PER_STEP
                            onStep(steps)
                        }
                        true
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = valueText,
                    style = WatchType.bigNumber,
                    color = if (focused) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onBackground,
                )
            }
            RoundStepButton(
                text = "+",
                onClick = {
                    onFocus()
                    onStep(1)
                    focusRequester.requestFocus()
                },
            )
        }
    }
}
