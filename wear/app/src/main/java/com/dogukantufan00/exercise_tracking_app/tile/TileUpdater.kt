package com.dogukantufan00.exercise_tracking_app.tile

import android.content.Context
import androidx.wear.tiles.TileService
import com.dogukantufan00.exercise_tracking_app.data.WatchProgram
import com.dogukantufan00.exercise_tracking_app.domain.DisplayWorkout
import com.dogukantufan00.exercise_tracking_app.domain.WatchThemeId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch

/**
 * Antrenman, program veya tema değişince Tile'ın yeniden çizilmesini ister (bkz. §15.8 madde 4).
 * WatchApp'te bir kez başlatılır; kendi kapsamında yaşar.
 */
object TileUpdater {
    fun start(
        context: Context,
        scope: CoroutineScope,
        workout: StateFlow<DisplayWorkout?>,
        program: StateFlow<WatchProgram?>,
        theme: StateFlow<WatchThemeId>,
    ) {
        val appContext = context.applicationContext
        scope.launch {
            // İlk değer mevcut durumdur; Tile'ı yeniden çizmek için bir şey değişmiş olmalı.
            combine(workout, program, theme) { _, _, _ -> Unit }
                .drop(1)
                .collect {
                    TileService.getUpdater(appContext).requestUpdate(WorkoutTileService::class.java)
                }
        }
    }
}
