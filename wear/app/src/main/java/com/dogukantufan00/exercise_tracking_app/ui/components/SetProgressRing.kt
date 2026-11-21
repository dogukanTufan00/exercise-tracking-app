package com.dogukantufan00.exercise_tracking_app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.Text
import com.dogukantufan00.exercise_tracking_app.ui.theme.WatchType

/**
 * Hareket listesindeki küçük set halkası: içinde "2/3" (hedef yoksa yalnızca set sayısı), halka hedefe göre dolar.
 * Hedefe ulaşınca halka tam dolar ve içinde ✓ görünür. Yalnızca gösterim; dokunma kartın kendisinde.
 */
@Composable
fun SetProgressRing(done: Int, target: Int?, modifier: Modifier = Modifier, size: Dp = 34.dp) {
    val track = MaterialTheme.colorScheme.outline
    val fill = MaterialTheme.colorScheme.primary
    val reached = target != null && target > 0 && done >= target
    val fraction = when {
        target == null || target <= 0 -> if (done > 0) 1f else 0f
        else -> (done.toFloat() / target).coerceIn(0f, 1f)
    }
    Box(modifier = modifier.size(size), contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.size(size)) {
            val stroke = 3.dp.toPx()
            val topLeft = Offset(stroke / 2, stroke / 2)
            val arcSize = Size(this.size.width - stroke, this.size.height - stroke)
            drawArc(track, 0f, 360f, useCenter = false, topLeft = topLeft, size = arcSize, style = Stroke(stroke))
            if (fraction > 0f) {
                drawArc(
                    color = fill,
                    startAngle = -90f,
                    sweepAngle = 360f * fraction,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(stroke, cap = StrokeCap.Round),
                )
            }
        }
        Text(
            text = when {
                reached -> "✓"
                target != null -> "$done/$target"
                else -> "$done"
            },
            style = WatchType.smallNumber,
            color = if (reached) fill else MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
        )
    }
}
