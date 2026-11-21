package com.dogukantufan00.exercise_tracking_app.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.MaterialTheme
import com.dogukantufan00.exercise_tracking_app.domain.WatchThemeId

/*
 * Saat renkleri telefonun paletinden gelir (bkz. docs/ARCHITECTURE.md §15.7). Saat OLED'dir; açık mavi tema
 * saatte koyu zeminle çizilir. Ekranlar renkleri yalnızca MaterialTheme.colorScheme'den okur.
 * primaryContainer = primary'nin %30'u background üzerine karıştırılmış (önceden hesaplandı).
 */

/** Koyu turuncu (varsayılan). */
private val DarkOrangeScheme = ColorScheme(
    primary = Color(0xFFFF7A1A),
    onPrimary = Color(0xFF1A0E00),
    primaryContainer = Color(0xFF593114),
    onPrimaryContainer = Color(0xFFF2F2F2),
    background = Color(0xFF121212),
    onBackground = Color(0xFFF2F2F2),
    surfaceContainerLow = Color(0xFF121212),
    surfaceContainer = Color(0xFF1E1E1E),
    surfaceContainerHigh = Color(0xFF2C2C2C),
    onSurface = Color(0xFFF2F2F2),
    onSurfaceVariant = Color(0xFF9A9A9A),
    outline = Color(0xFF2C2C2C),
    outlineVariant = Color(0xFF2C2C2C),
    error = Color(0xFFFF6B6B),
    onError = Color(0xFF3A0000),
)

/** Kırmızı siyah. */
private val RedBlackScheme = ColorScheme(
    primary = Color(0xFFE5383B),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFF4C1819),
    onPrimaryContainer = Color(0xFFF5F5F5),
    background = Color(0xFF0B0B0B),
    onBackground = Color(0xFFF5F5F5),
    surfaceContainerLow = Color(0xFF0B0B0B),
    surfaceContainer = Color(0xFF191919),
    surfaceContainerHigh = Color(0xFF2A2A2A),
    onSurface = Color(0xFFF5F5F5),
    onSurfaceVariant = Color(0xFF9C9C9C),
    outline = Color(0xFF2A2A2A),
    outlineVariant = Color(0xFF2A2A2A),
    error = Color(0xFFFF6B6B),
    onError = Color(0xFF3A0000),
)

/** Sarı lacivert. */
private val YellowNavyScheme = ColorScheme(
    primary = Color(0xFFFFC93C),
    onPrimary = Color(0xFF1E1600),
    primaryContainer = Color(0xFF574F32),
    onPrimaryContainer = Color(0xFFEEF2F8),
    background = Color(0xFF0F1B2D),
    onBackground = Color(0xFFEEF2F8),
    surfaceContainerLow = Color(0xFF0F1B2D),
    surfaceContainer = Color(0xFF172A44),
    surfaceContainerHigh = Color(0xFF24395A),
    onSurface = Color(0xFFEEF2F8),
    onSurfaceVariant = Color(0xFF93A3BC),
    outline = Color(0xFF24395A),
    outlineVariant = Color(0xFF24395A),
    error = Color(0xFFFF6B6B),
    onError = Color(0xFF3A0000),
)

/** Açık mavi, saatte koyu zeminle (OLED ve göz için). */
private val LightBlueScheme = ColorScheme(
    primary = Color(0xFF5B8DEF),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFF26395C),
    onPrimaryContainer = Color(0xFFEEF2F8),
    background = Color(0xFF10151D),
    onBackground = Color(0xFFEEF2F8),
    surfaceContainerLow = Color(0xFF10151D),
    surfaceContainer = Color(0xFF1B2430),
    surfaceContainerHigh = Color(0xFF2A3646),
    onSurface = Color(0xFFEEF2F8),
    onSurfaceVariant = Color(0xFF93A0B2),
    outline = Color(0xFF2A3646),
    outlineVariant = Color(0xFF2A3646),
    error = Color(0xFFFF6B6B),
    onError = Color(0xFF3A0000),
)

/** Seçili temanın şeması. */
private fun schemeOf(themeId: WatchThemeId): ColorScheme = when (themeId) {
    WatchThemeId.DarkOrange -> DarkOrangeScheme
    WatchThemeId.RedBlack -> RedBlackScheme
    WatchThemeId.YellowNavy -> YellowNavyScheme
    WatchThemeId.LightBlue -> LightBlueScheme
}

/** Saatin teması; tüm ekranlar bunun içinde çizilir. [themeId] telefondaki seçimi izler. */
@Composable
fun WatchTheme(themeId: WatchThemeId, content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = schemeOf(themeId), content = content)
}
