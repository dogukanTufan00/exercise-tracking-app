package com.dogukantufan00.exercise_tracking_app.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.OutlinedButton
import androidx.wear.compose.material3.Text
import androidx.compose.foundation.layout.PaddingValues
import com.dogukantufan00.exercise_tracking_app.ui.theme.WatchType

/** Hareket ekranında döner çerçevenin ve −/+ düğmelerinin değiştirdiği alan. */
enum class SetField { WEIGHT, REPS }

/**
 * Hareket ekranının set girişi: ağırlık ve tekrar tek satırda büyük Oswald sayılarla ("62,5 × 8"), altında
 * odaktaki alanın −/+ düğmeleri. Sayıya dokunmak o alanı seçer; seçili alan vurgu renginde ve altı çizili.
 * Döner çerçeve (Galaxy Watch'ta dokunmatik çerçeve) her zaman seçili alanı değiştirir.
 *
 * [onStep] alanı ve adım sayısını alır (düğme ±1, döner çerçeve birikime göre); adım büyüklüğü ViewModel'dedir.
 */
@Composable
fun SetInput(
    weightText: String,
    repsText: String,
    focused: SetField,
    onFocus: (SetField) -> Unit,
    onStep: (SetField, Int) -> Unit,
    doneSets: Int,
    targetSets: Int?,
    modifier: Modifier = Modifier,
) {
    val focusRequester = remember { FocusRequester() }
    var pendingPixels by remember { mutableFloatStateOf(0f) }

    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .focusRequester(focusRequester)
            .onRotaryScrollEvent { event ->
                pendingPixels += event.verticalScrollPixels
                val steps = (pendingPixels / ROTARY_PIXELS_PER_STEP).toInt()
                if (steps != 0) {
                    pendingPixels -= steps * ROTARY_PIXELS_PER_STEP
                    onStep(focused, steps)
                }
                true
            }
            .focusable(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            BigValue(
                text = weightText,
                unit = "kg",
                selected = focused == SetField.WEIGHT,
                onClick = {
                    onFocus(SetField.WEIGHT)
                    focusRequester.requestFocus()
                },
            )
            Text(
                text = "×",
                style = WatchType.number,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 4.dp),
            )
            BigValue(
                text = repsText,
                unit = "tekrar",
                selected = focused == SetField.REPS,
                onClick = {
                    onFocus(SetField.REPS)
                    focusRequester.requestFocus()
                },
            )
        }
        SetDots(done = doneSets, target = targetSets, modifier = Modifier.padding(top = 2.dp))
        // −/+ noktaların altında: ilk bakışta sayılar ve "SET TAMAM" görünür, düğmeler aşağı kaydırınca gelir.
        Row(
            modifier = Modifier.padding(top = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            RoundStepButton(
                text = "−",
                onClick = {
                    onStep(focused, -1)
                    focusRequester.requestFocus()
                },
            )
            Text(
                text = if (focused == SetField.WEIGHT) "±2,5 kg" else "±1 tekrar",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.widthIn(min = 56.dp),
            )
            RoundStepButton(
                text = "+",
                onClick = {
                    onStep(focused, 1)
                    focusRequester.requestFocus()
                },
            )
        }
    }
}

/** Büyük sayı ve altında birimi; seçiliyse vurgu renginde ve altı çizili. Dokunma alanı ≥ 56 × 64 dp. */
@Composable
private fun BigValue(text: String, unit: String, selected: Boolean, onClick: () -> Unit) {
    val accent = MaterialTheme.colorScheme.primary
    Column(
        modifier = Modifier
            .widthIn(min = 56.dp)
            .heightIn(min = 64.dp)
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = text,
            style = WatchType.bigNumber,
            color = if (selected) accent else MaterialTheme.colorScheme.onBackground,
            maxLines = 1,
            modifier = Modifier.drawBehind {
                if (selected) {
                    val y = size.height - 1.dp.toPx()
                    drawLine(accent, Offset(0f, y), Offset(size.width, y), strokeWidth = 2.dp.toPx())
                }
            },
        )
        Text(
            text = unit,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.height(16.dp),
        )
    }
}

/** En fazla bu kadar nokta çizilir; fazlası "5/12 set" yazısıyla gösterilir. */
private const val MAX_DOTS = 8

/**
 * Set noktaları: yapılan setler dolu (vurgu rengi), kalan hedef setler boş halka. Hedef yoksa yapılan setler ve
 * sıradaki için bir boş nokta. Çok set varsa nokta yerine yazı.
 */
@Composable
fun SetDots(done: Int, target: Int?, modifier: Modifier = Modifier) {
    val total = maxOf(target ?: (done + 1), done)
    val accent = MaterialTheme.colorScheme.primary
    val empty = MaterialTheme.colorScheme.onSurfaceVariant
    if (total > MAX_DOTS) {
        Text(
            text = if (target != null) "$done/$target set" else "$done set",
            style = MaterialTheme.typography.labelSmall,
            color = empty,
            modifier = modifier,
        )
        return
    }
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(total) { index ->
            Canvas(modifier = Modifier.size(9.dp)) {
                if (index < done) {
                    drawCircle(accent)
                } else {
                    drawCircle(empty, radius = size.minDimension / 2 - 0.75.dp.toPx(), style = Stroke(1.5.dp.toPx()))
                }
            }
        }
    }
}

/** 48 dp yuvarlak, ince çerçeveli −/+ düğmesi. */
@Composable
fun RoundStepButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.size(48.dp),
        shape = CircleShape,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
        contentPadding = PaddingValues(0.dp),
    ) {
        Text(
            text = text,
            style = WatchType.number,
            color = MaterialTheme.colorScheme.onBackground,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
