package com.dogukantufan00.exercise_tracking_app.domain

/**
 * Saatin temaları; adlar telefondaki `AppThemeId.name` ile birebir aynıdır (bkz. docs/ARCHITECTURE.md §15.7).
 * Saf Kotlin: Android import etmez, JVM testlidir.
 */
enum class WatchThemeId { DarkOrange, RedBlack, YellowNavy, LightBlue }

/** Telefonun yazdığı tema adını çözer. Boş, eksik ya da bilinmeyen değerde [WatchThemeId.DarkOrange] döner. */
fun watchThemeIdOf(name: String?): WatchThemeId = when (name) {
    "darkOrange" -> WatchThemeId.DarkOrange
    "redBlack" -> WatchThemeId.RedBlack
    "yellowNavy" -> WatchThemeId.YellowNavy
    "lightBlue" -> WatchThemeId.LightBlue
    else -> WatchThemeId.DarkOrange
}
