package com.dogukantufan00.exercise_tracking_app.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.OutlinedButton

/** Kart köşe yarıçapı: telefondaki 12'nin saatteki karşılığı (yuvarlak ekranda biraz daha yumuşak). */
val CardShape = RoundedCornerShape(16.dp)

private val CardPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp)

/**
 * Telefondaki minimal kartın saat karşılığı: dolgusuz, ince çerçeveli, tam genişlik, en az 52 dp yükseklik.
 * [accent] çerçeveyi vurgu rengine çevirir (ör. süren dinlenme). Bir ekranda dolu düğme yalnızca bir tane olur
 * ([AccentCardButton]); diğer her şey bu karttır.
 */
@Composable
fun CardButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    accent: Boolean = false,
    content: @Composable RowScope.() -> Unit,
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().heightIn(min = 52.dp),
        shape = CardShape,
        border = BorderStroke(
            width = if (accent) 1.5.dp else 1.dp,
            color = if (accent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
        ),
        contentPadding = CardPadding,
        content = content,
    )
}

/** Ekranın tek dolu vurgu düğmesi (ör. bugünün günü). */
@Composable
fun AccentCardButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable RowScope.() -> Unit,
) {
    Button(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().heightIn(min = 56.dp),
        shape = CardShape,
        colors = ButtonDefaults.buttonColors(),
        contentPadding = CardPadding,
        content = content,
    )
}
