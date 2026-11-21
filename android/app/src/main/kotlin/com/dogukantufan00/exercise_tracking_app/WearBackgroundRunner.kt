package com.dogukantufan00.exercise_tracking_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Telefon uygulaması açık değilken saat olaylarını işler (bkz. docs/ARCHITECTURE.md §15.5).
 *
 * Saatten olay gelince [PhoneWearListenerService] [onEventQueued]'u çağırır. Uygulamanın Flutter'ı olayları
 * dinliyorsa (ön planda ya da arka planda canlı) hiçbir şey yapılmaz; dinlemiyorsa ekransız bir Flutter motoru
 * başlatılır ve Dart'taki `wearBackgroundMain` çalıştırılır. Dart işini bitirince `backgroundDone` der ve motor
 * kapatılır; en geç [TIMEOUT_MS] sonra yine kapatılır. Motor çalışırken yeni olay gelirse, bitince bir tur daha
 * çalışır. Bitişte kuyruk yeniden bildirilir ki bu arada açılan uygulama kalan olayları alsın.
 * Tüm durum ana iş parçacığında değişir.
 */
object WearBackgroundRunner {
    private const val TAG = "WearBackground"
    private const val ENTRYPOINT = "wearBackgroundMain"
    private const val TIMEOUT_MS = 30_000L

    private val mainHandler = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var rerun = false
    private val timeout = Runnable {
        Log.w(TAG, "Arka plan işi zaman aşımına uğradı; motor kapatılıyor")
        finish()
    }

    /** Ekransız motor şu an çalışıyor mu (ana iş parçacığında okunur). */
    @Volatile
    var isRunning: Boolean = false
        private set

    /** Kuyruğa olay eklendi; gerekirse ekransız motoru başlatır. Herhangi bir iş parçacığından çağrılabilir. */
    fun onEventQueued(context: Context) {
        val app = context.applicationContext
        mainHandler.post { startIfNeeded(app) }
    }

    private fun startIfNeeded(context: Context) {
        appContext = context
        if (WearEventNotifier.sink != null) return // Uygulama dinliyor; olayı o işler.
        if (engine != null) {
            rerun = true
            return
        }
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
            val newEngine = FlutterEngine(context)
            WearBridge.attach(context, newEngine.dartExecutor.binaryMessenger) {
                mainHandler.post { finish() }
            }
            engine = newEngine
            isRunning = true
            rerun = false
            mainHandler.postDelayed(timeout, TIMEOUT_MS)
            newEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT),
            )
            Log.i(TAG, "Saat olayları arka planda işleniyor")
        } catch (e: Exception) {
            Log.w(TAG, "Arka plan motoru başlatılamadı; olaylar uygulama açılınca işlenecek", e)
            finish()
        }
    }

    private fun finish() {
        mainHandler.removeCallbacks(timeout)
        val finished = engine
        engine = null
        isRunning = false
        finished?.destroy()
        // Bu arada açılan uygulama kuyruğu boş görmüş olabilir: yeniden haber ver.
        WearEventNotifier.notifyAvailable()
        val context = appContext
        if (rerun && context != null) {
            rerun = false
            startIfNeeded(context)
        }
    }

    /** Motoru başlatan uygulama bağlamı (motor çalışırken gelen olaylar için bir tur daha). */
    private var appContext: Context? = null
}
