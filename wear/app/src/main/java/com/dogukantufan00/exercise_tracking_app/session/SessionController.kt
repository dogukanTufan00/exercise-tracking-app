package com.dogukantufan00.exercise_tracking_app.session

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Antrenman servisini (WorkoutSessionService, foreground + Ongoing Activity) yönetir (§15.8 madde 5).
 *
 * Android 12+ arka plandan foreground service başlatmayı yasaklar; bu yüzden servis yalnızca ön plandaki
 * [Activity]'den başlatılır: MainActivity etkin antrenman ve izin durumu her değiştiğinde [sync] çağırır.
 */
object SessionController {
    private const val TAG = "SessionController"

    /** Gerekli izinler (Android 14 health türü + bildirim): ACTIVITY_RECOGNITION ve (API 33+) POST_NOTIFICATIONS. */
    fun requiredPermissions(): Array<String> {
        val permissions = mutableListOf(Manifest.permission.ACTIVITY_RECOGNITION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        return permissions.toTypedArray()
    }

    /**
     * [workoutActive] ve izinler verilmişse servisi başlatır (çalışıyorsa bir şey yapmaz);
     * [workoutActive] false ise servisi durdurur. İzin yoksa servis başlatılmaz (sayaç ekran açıkken çalışır).
     * İzni burada istemez: MainActivity ilk antrenmanda bir kez sorar (aynı soru iki kez çıkmasın).
     */
    fun sync(activity: Activity, workoutActive: Boolean) {
        val intent = Intent(activity, WorkoutSessionService::class.java)
        if (!workoutActive) {
            activity.stopService(intent)
            return
        }
        val missing = requiredPermissions().filter {
            ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            try {
                activity.startForegroundService(intent)
            } catch (e: RuntimeException) {
                // Arka plan kısıtı vb.; antrenman ekranı çalışmaya devam etsin.
                Log.w(TAG, "Antrenman servisi başlatılamadı", e)
            }
            return
        }
        Log.i(TAG, "İzin yok, antrenman servisi başlatılmadı: $missing")
    }
}
