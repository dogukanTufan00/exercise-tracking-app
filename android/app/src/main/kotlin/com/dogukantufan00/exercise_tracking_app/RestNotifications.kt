package com.dogukantufan00.exercise_tracking_app

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dinlenme sayacının telefondaki bildirimi ve titreşimi (docs/ARCHITECTURE.md §16.2).
 *
 * MethodChannel `exercise_tracker/rest` metotlarını uygular (Dart tarafı: `lib/data/rest/rest_notifier.dart`):
 * - `showCountdown` `{endsAtMillis, totalSeconds, title}`: kalıcı geri sayım bildirimi (Android kronometresi).
 * - `cancel`: geri sayım bildirimini kaldırır.
 * - `notifyFinished` `{vibrate}`: geri sayımı kaldırır; `vibrate` true ise "Dinlenme bitti" bildirimi ya da titreşim.
 * - `requestPermission`: Android 13+ bildirim izni (bir kez).
 *
 * Hatalar Dart'a gitmez: her metot başarısızsa `null` ya da `false` döner.
 * [activity] yalnızca izin isteği için tutulur.
 */
class RestNotifications(private val activity: Activity) {

    private val context: Context = activity.applicationContext
    private val manager: NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    /** Kanalları ve metot işleyicisini Flutter mesajlaşmasına bağlar. */
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            handle(call, result)
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "showCountdown" -> {
                    val args = call.arguments as? Map<*, *>
                    val endsAtMillis = (args?.get("endsAtMillis") as? Number)?.toLong()
                    if (endsAtMillis != null) {
                        val title = (args?.get("title") as? String) ?: DEFAULT_TITLE
                        showCountdown(endsAtMillis, title)
                    }
                    result.success(null)
                }
                "cancel" -> {
                    manager.cancel(COUNTDOWN_ID)
                    result.success(null)
                }
                "notifyFinished" -> {
                    val args = call.arguments as? Map<*, *>
                    val vibrate = args?.get("vibrate") as? Boolean ?: false
                    notifyFinished(vibrate)
                    result.success(null)
                }
                "requestPermission" -> result.success(requestPermission())
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Dinlenme bildirimi hatası: ${call.method}", e)
            result.success(if (call.method == "requestPermission") false else null)
        }
    }

    /** Kalıcı geri sayım bildirimi. Süre [endsAtMillis] anına kadar sayar, sonra kendiliğinden kalkar. */
    private fun showCountdown(endsAtMillis: Long, title: String) {
        val remaining = endsAtMillis - System.currentTimeMillis()
        // Süresi dolmuş sayaç gösterilmez (setTimeoutAfter(0) "zaman aşımı yok" anlamına gelir).
        if (remaining <= 0L) {
            manager.cancel(COUNTDOWN_ID)
            return
        }
        ensureChannels()

        val builder = newBuilder(COUNTDOWN_CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText("Kalan süre")
            .setContentIntent(launchIntent())
            .setWhen(endsAtMillis)
            .setShowWhen(true)
            .setOngoing(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.setUsesChronometer(true).setChronometerCountDown(true)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setOnlyAlertOnce(true).setTimeoutAfter(remaining)
        }
        manager.notify(COUNTDOWN_ID, builder.build())
    }

    /** Geri sayımı kaldırır; [vibrate] true ise bitti bildirimi ya da (izin yoksa) doğrudan titreşim. */
    private fun notifyFinished(vibrate: Boolean) {
        manager.cancel(COUNTDOWN_ID)
        if (!vibrate) return

        if (hasNotificationPermission()) {
            ensureChannels()
            val builder = newBuilder(DONE_CHANNEL)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(DONE_TITLE)
                .setContentIntent(launchIntent())
                .setAutoCancel(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                builder.setTimeoutAfter(DONE_TIMEOUT_MILLIS)
            } else {
                @Suppress("DEPRECATION")
                builder.setVibrate(VIBRATION_PATTERN)
            }
            manager.notify(DONE_ID, builder.build())
        } else {
            vibrateNow()
        }
    }

    /**
     * Bildirim izni (Android 13+) bir kez istenir. İzin zaten varsa ya da sürüm 13 öncesiyse `true`.
     * İzin yoksa istek başlatılır ve `false` döner; sonuç beklenmez.
     */
    private fun requestPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        if (hasPostNotificationsPermission()) return true
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST_CODE)
        return false
    }

    /** Bildirim izni var ve bildirimler sistem ayarlarında açık. */
    private fun hasNotificationPermission(): Boolean {
        if (!hasPostNotificationsPermission()) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.N || manager.areNotificationsEnabled()
    }

    private fun hasPostNotificationsPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    /** Bildirim izni yokken bitişte doğrudan titreşim (alarm kullanımı, aynı desen). */
    private fun vibrateNow() {
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (!vibrator.hasVibrator()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createWaveform(VIBRATION_PATTERN, -1)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                vibrator.vibrate(
                    effect,
                    VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
                )
            } else {
                vibrator.vibrate(
                    effect,
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build(),
                )
            }
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(VIBRATION_PATTERN, -1)
        }
    }

    /** Kanalları ilk kullanımda oluşturur (Android 8+). Android, var olan kanalın ayarlarını değiştirmez. */
    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val countdown = NotificationChannel(
            COUNTDOWN_CHANNEL,
            "Dinlenme sayacı",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            setSound(null, null)
            enableVibration(false)
        }
        val done = NotificationChannel(
            DONE_CHANNEL,
            "Dinlenme bitti",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            setSound(null, null)
            enableVibration(true)
            vibrationPattern = VIBRATION_PATTERN
        }
        manager.createNotificationChannel(countdown)
        manager.createNotificationChannel(done)
    }

    /** Sürüm 8 öncesinde kanal kavramı yoktur; o zaman kanalsız oluşturucu kullanılır. */
    @Suppress("DEPRECATION")
    private fun newBuilder(channelId: String): Notification.Builder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            Notification.Builder(context)
        }
    }

    /** Bildirime dokununca uygulama açılır. */
    private fun launchIntent(): PendingIntent? {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private companion object {
        const val TAG = "RestNotifications"
        const val CHANNEL = "exercise_tracker/rest"

        const val COUNTDOWN_CHANNEL = "rest_countdown"
        const val DONE_CHANNEL = "rest_done"

        const val COUNTDOWN_ID = 7001
        const val DONE_ID = 7002

        const val DONE_TITLE = "Dinlenme bitti"
        const val DONE_TIMEOUT_MILLIS = 15_000L
        const val DEFAULT_TITLE = "Antrenman"

        const val PERMISSION_REQUEST_CODE = 7003

        /** Bitiş titreşimi: bekle 0, titre 300, bekle 150, titre 300 (ms). */
        val VIBRATION_PATTERN = longArrayOf(0, 300, 150, 300)
    }
}
