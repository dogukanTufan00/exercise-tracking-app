package com.dogukantufan00.exercise_tracking_app.ui

/** Tile'dan ya da telefondan gelen açılış isteği (bkz. §15.8 madde 5; Intent ekstraları MainActivity'de okunur). */
sealed interface LaunchRequest {
    /** Program gününü hemen başlat. */
    data class StartDay(val dayId: Long) : LaunchRequest

    /** Boş antrenman başlat. */
    data object StartEmpty : LaunchRequest

    /** Başlatma ekranını (ana ekran, antrenman yoksa) göster. */
    data object OpenStart : LaunchRequest
}
