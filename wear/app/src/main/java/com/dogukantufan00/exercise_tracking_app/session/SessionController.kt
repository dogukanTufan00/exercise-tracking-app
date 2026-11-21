package com.dogukantufan00.exercise_tracking_app.session

import android.app.Activity

/**
 * Antrenman servisini (WorkoutSessionService, foreground + Ongoing Activity) yönetir (§15.8 madde 5).
 *
 * Android 12+ arka plandan foreground service başlatmayı yasaklar; bu yüzden servis yalnızca ön plandaki
 * [Activity]'den başlatılır: MainActivity etkin antrenman ve izin durumu her değiştiğinde [sync] çağırır.
 */
object SessionController {
    /** Gerekli izinler (Android 14 health türü + bildirim): ACTIVITY_RECOGNITION ve (API 33+) POST_NOTIFICATIONS. */
    fun requiredPermissions(): Array<String> = TODO("Ajan BE uygular")

    /**
     * [workoutActive] ve izinler verilmişse servisi başlatır (çalışıyorsa bir şey yapmaz);
     * [workoutActive] false ise servisi durdurur. İzin yoksa servis başlatılmaz (sayaç ekran açıkken çalışır).
     */
    fun sync(activity: Activity, workoutActive: Boolean): Unit = TODO("Ajan BE uygular")
}
