package com.dogukantufan00.exercise_tracking_app.ui.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.Text
import com.dogukantufan00.exercise_tracking_app.domain.RestProgress
import com.dogukantufan00.exercise_tracking_app.domain.formatDuration

/**
 * Arka planda süren dinlenme sayacının küçük göstergesi: "Dinlenme 0:45". Dokununca dinlenme ekranı açılır.
 * Yalnızca sayaç çalışırken gösterilir (çağıran kontrol eder).
 */
@Composable
fun RestIndicator(rest: RestProgress, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.filledTonalButtonColors(),
    ) {
        Text(text = "Dinlenme ${formatDuration(rest.remainingSeconds)}")
    }
}
