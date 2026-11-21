package com.dogukantufan00.exercise_tracking_app.tile

import com.dogukantufan00.exercise_tracking_app.data.WatchProgram
import com.dogukantufan00.exercise_tracking_app.domain.DisplayWorkout
import com.dogukantufan00.exercise_tracking_app.domain.WatchThemeId
import com.dogukantufan00.exercise_tracking_app.domain.suggestedDay
import java.time.DayOfWeek

/*
 * Tile'ın gösterdiği durum (bkz. docs/ARCHITECTURE.md §15.8 madde 4). Saf Kotlin: Android import etmez.
 */

/** Tile'ın üç durumundan biri. */
sealed interface WorkoutTileState {
    /** Antrenman sürüyor: "Devam et". */
    data class Active(val title: String, val setCount: Int) : WorkoutTileState

    /** Bugüne planlı gün var: "Başla" (doğrudan başlatır). */
    data class Today(val dayId: Long, val dayName: String, val exerciseCount: Int) : WorkoutTileState

    /** Ne antrenman ne bugünkü gün: "Antrenman başlat". [hasProgram] başlatma ekranının gün seçip seçmeyeceğini belirler. */
    data class StartNew(val hasProgram: Boolean) : WorkoutTileState
}

/** Telefondan gelen verilerden Tile durumunu hesaplar. Etkin antrenman her zaman önceliklidir. */
fun tileStateOf(workout: DisplayWorkout?, program: WatchProgram?, today: DayOfWeek): WorkoutTileState {
    if (workout != null) {
        val sets = workout.exercises.sumOf { it.sets.size }
        return WorkoutTileState.Active(workout.title, sets)
    }
    val day = program?.let { suggestedDay(it, today) }
    if (day != null) {
        return WorkoutTileState.Today(day.dayId, day.name, day.exercises.size)
    }
    return WorkoutTileState.StartNew(hasProgram = program != null)
}

/** Tile renkleri (bkz. §15.7 tablosu). Uygulama temasıyla aynı değerler, saatte koyu zemin. */
data class TilePalette(
    val background: Int,
    val surface: Int,
    val onSurface: Int,
    val muted: Int,
    val primary: Int,
    val onPrimary: Int,
)

/** Seçili temanın Tile paleti. */
fun tilePaletteOf(themeId: WatchThemeId): TilePalette = when (themeId) {
    WatchThemeId.DarkOrange -> TilePalette(
        background = 0xFF121212.toInt(),
        surface = 0xFF1E1E1E.toInt(),
        onSurface = 0xFFF2F2F2.toInt(),
        muted = 0xFF9A9A9A.toInt(),
        primary = 0xFFFF7A1A.toInt(),
        onPrimary = 0xFF1A0E00.toInt(),
    )
    WatchThemeId.RedBlack -> TilePalette(
        background = 0xFF0B0B0B.toInt(),
        surface = 0xFF191919.toInt(),
        onSurface = 0xFFF5F5F5.toInt(),
        muted = 0xFF9C9C9C.toInt(),
        primary = 0xFFE5383B.toInt(),
        onPrimary = 0xFFFFFFFF.toInt(),
    )
    WatchThemeId.YellowNavy -> TilePalette(
        background = 0xFF0F1B2D.toInt(),
        surface = 0xFF172A44.toInt(),
        onSurface = 0xFFEEF2F8.toInt(),
        muted = 0xFF93A3BC.toInt(),
        primary = 0xFFFFC93C.toInt(),
        onPrimary = 0xFF1E1600.toInt(),
    )
    WatchThemeId.LightBlue -> TilePalette(
        background = 0xFF10151D.toInt(),
        surface = 0xFF1B2430.toInt(),
        onSurface = 0xFFEEF2F8.toInt(),
        muted = 0xFF93A0B2.toInt(),
        primary = 0xFF5B8DEF.toInt(),
        onPrimary = 0xFFFFFFFF.toInt(),
    )
}
