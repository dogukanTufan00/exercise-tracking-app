package com.dogukantufan00.exercise_tracking_app

/**
 * MainActivity'yi Tile'dan açan Intent ekstraları (§15.8 madde 4).
 * - [EXTRA_START_DAY_ID] (Long): o program gününü hemen başlat.
 * - [EXTRA_START_EMPTY] (Boolean): boş antrenman başlat.
 * - [EXTRA_OPEN_START] (Boolean): başlatma ekranını (gün seçimi) aç.
 * Ekstra yoksa uygulama normal açılır (antrenman sürüyorsa hareket listesi).
 */
object LaunchActions {
    const val EXTRA_START_DAY_ID = "com.dogukantufan00.exercise_tracking_app.START_DAY_ID"
    const val EXTRA_START_EMPTY = "com.dogukantufan00.exercise_tracking_app.START_EMPTY"
    const val EXTRA_OPEN_START = "com.dogukantufan00.exercise_tracking_app.OPEN_START"
}
