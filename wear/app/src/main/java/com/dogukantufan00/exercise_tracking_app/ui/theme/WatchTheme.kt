package com.dogukantufan00.exercise_tracking_app.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.MaterialTheme

/** Saatin tek renk şeması: koyu zemin, telefonun "koyu turuncu" vurgusu. Renkler ekranlarda sabit yazılmaz. */
private val WatchColorScheme = ColorScheme(
    primary = Color(0xFFFF8A3D),
    onPrimary = Color(0xFF2B1400),
    primaryContainer = Color(0xFF4A2410),
    onPrimaryContainer = Color(0xFFFFDCC2),
    background = Color(0xFF000000),
    onBackground = Color(0xFFF5F5F5),
    surfaceContainer = Color(0xFF1E1E1E),
    surfaceContainerHigh = Color(0xFF2A2A2A),
    onSurfaceVariant = Color(0xFFB0B0B0),
    outline = Color(0xFF5A5A5A),
    error = Color(0xFFFF6B6B),
    onError = Color(0xFF3A0000),
)

/** Saatin teması; tüm ekranlar bunun içinde çizilir. */
@Composable
fun WatchTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = WatchColorScheme, content = content)
}
