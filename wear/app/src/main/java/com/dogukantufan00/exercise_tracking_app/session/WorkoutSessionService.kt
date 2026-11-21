package com.dogukantufan00.exercise_tracking_app.session

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status
import com.dogukantufan00.exercise_tracking_app.MainActivity
import com.dogukantufan00.exercise_tracking_app.R
import com.dogukantufan00.exercise_tracking_app.WatchApp
import com.dogukantufan00.exercise_tracking_app.domain.RestProgress
import com.dogukantufan00.exercise_tracking_app.domain.formatDuration
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/**
 * Etkin antrenman sürerken çalışan ön plan servisi (tür `health`, bkz. docs/ARCHITECTURE.md §15.8 madde 5).
 *
 * Kadranda ve son uygulamalarda Ongoing Activity gösterir; dinlenme sayacı sürerken durumu "Dinlenme m:ss" yapar.
 * Sayaç çalışırken kısmi uyanık kilidi (WakeLock) tutar ki ekran kapalıyken de bitişte titreşim gerçekleşsin.
 * Etkin antrenman bitince (repository `workout` null) kendini durdurur.
 *
 * Başlatma [SessionController.sync] üzerinden, ön plandaki bir Activity'den yapılır (Android 12+ kısıtı).
 */
class WorkoutSessionService : Service() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var wakeLock: PowerManager.WakeLock? = null
    private var observing = false

    override fun onCreate() {
        super.onCreate()
        createChannel()
        wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG)
            .apply { setReferenceCounted(false) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Android 12+: ön plan servisi, başlatıldıktan kısa süre içinde startForeground çağrılmalı.
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            plainNotification(TITLE),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH,
        )
        if (!observing) {
            observing = true
            observe()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        scope.cancel()
        wakeLock?.takeIf { it.isHeld }?.release()
        super.onDestroy()
    }

    private fun observe() {
        val app = application as WatchApp
        val rest = app.restTimer.rest

        // Durum metni: antrenman başlığı; dinlenmede "Dinlenme m:ss". Yalnızca değişince bildirim güncellenir.
        scope.launch {
            combine(app.syncRepository.workout, rest) { workout, progress ->
                workout?.let { statusText(it.title, progress) }
            }
                .distinctUntilChanged()
                .collect { text ->
                    if (text == null) {
                        stopWorkoutSession()
                    } else {
                        publish(text)
                    }
                }
        }

        // Kısmi uyanık kilidi: her dinlenme başlangıcında ve süre değişince, en fazla sayaç süresi + 10 sn.
        scope.launch {
            rest.map { it?.totalSeconds }
                .distinctUntilChanged()
                .collect { total ->
                    val lock = wakeLock ?: return@collect
                    if (total == null) {
                        if (lock.isHeld) lock.release()
                    } else {
                        lock.acquire(total * 1000L + WAKE_LOCK_MARGIN_MILLIS)
                    }
                }
        }
    }

    private fun stopWorkoutSession() {
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /** Ongoing Activity'yi günceller; bildirim aynı kimlikle yeniden yayınlanır. */
    private fun publish(text: String) {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_workout)
            .setContentTitle(TITLE)
            .setContentText(text)
            .setContentIntent(openAppIntent())
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        OngoingActivity.Builder(this, NOTIFICATION_ID, builder)
            .setStaticIcon(R.drawable.ic_workout)
            .setTouchIntent(openAppIntent())
            .setTitle(TITLE)
            .setStatus(Status.forPart(Status.TextPart(text)))
            .build()
            .apply(this)
    }

    private fun plainNotification(text: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_workout)
            .setContentTitle(TITLE)
            .setContentText(text)
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        this,
        0,
        Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun createChannel() {
        val channel = NotificationChannel(CHANNEL_ID, TITLE, NotificationManager.IMPORTANCE_LOW)
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "workout_session"
        const val NOTIFICATION_ID = 2501
        private const val TITLE = "Antrenman"
        private const val WAKE_LOCK_TAG = "exercise_tracker:rest"
        private const val WAKE_LOCK_MARGIN_MILLIS = 10_000L

        /** Ekranda ve bildirimde gösterilen durum metni. */
        fun statusText(workoutTitle: String, rest: RestProgress?): String =
            if (rest == null) workoutTitle else "Dinlenme ${formatDuration(rest.remainingSeconds)}"
    }
}
