package com.dogukantufan00.exercise_tracking_app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.Text
import com.dogukantufan00.exercise_tracking_app.domain.RestProgress
import com.dogukantufan00.exercise_tracking_app.domain.formatDuration
import com.dogukantufan00.exercise_tracking_app.ui.theme.WatchType

/**
 * Arka planda süren dinlenme sayacının küçük göstergesi: vurgu çerçeveli kart, küçük halka ve "Dinlenme 0:45".
 * Dokununca dinlenme ekranı açılır. Yalnızca sayaç çalışırken gösterilir (çağıran kontrol eder).
 */
@Composable
fun RestIndicator(rest: RestProgress, onClick: () -> Unit) {
    CardButton(onClick = onClick, accent = true) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
        ) {
            CircularProgressIndicator(
                progress = { rest.remainingFraction },
                modifier = Modifier.size(22.dp),
                strokeWidth = 3.dp,
            )
            Text(
                text = "Dinlenme",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = formatDuration(rest.remainingSeconds),
                style = WatchType.number,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}
