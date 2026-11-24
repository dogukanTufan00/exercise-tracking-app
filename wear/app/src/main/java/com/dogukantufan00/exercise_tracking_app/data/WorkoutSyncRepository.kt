package com.dogukantufan00.exercise_tracking_app.data

import com.dogukantufan00.exercise_tracking_app.domain.DisplayWorkout
import kotlinx.coroutines.flow.StateFlow

/**
 * Saat arayüzünün veriye tek giriş kapısı (bkz. docs/ARCHITECTURE.md §15.6).
 *
 * Gerçeği `PhoneSyncRepository` (Data Layer); arayüz önizlemeleri ve testler için sahtesi yazılabilir.
 * Metotlar hata fırlatmaz: telefon erişilemezse olay kuyrukta bekler ve sonra gönderilir.
 */
interface WorkoutSyncRepository {
    /** Saatte gösterilecek antrenman (iyimser durum); etkin antrenman yoksa null. */
    val workout: StateFlow<DisplayWorkout?>

    /** Telefon şu an erişilebilir mi (yeteneği olan bağlı düğüm var mı). */
    val phoneReachable: StateFlow<Boolean>

    /** Etkin antrenmandaki harekete set ekler (önce iyimser olarak görünür, sonra telefona gönderilir). */
    suspend fun addSet(workoutExerciseId: Long, weightKg: Double, reps: Int)

    /** Telefonun onayladığı bir seti siler. Bekleyen sette çağrılmaz. */
    suspend fun deleteSet(setId: Long)

    /** Telefonun yayınladığı etkin program; yoksa null (§15.8). */
    val program: StateFlow<WatchProgram?>

    /**
     * Telefona gönderilmiş ama henüz uygulanmamış antrenman başlatma isteği; yoksa null.
     * Telefon olayı uyguladığında (appliedEventIds) ya da [cancelPendingStart] ile null olur.
     */
    val pendingStart: StateFlow<PendingStart?>

    /**
     * Antrenman başlatır ([programDayId] null → boş antrenman): StartWorkoutEvent kuyruğa eklenir ve gönderilir.
     * Zaten bekleyen bir başlatma varsa önce o iptal edilir (en fazla bir bekleyen başlatma).
     */
    suspend fun startWorkout(programDayId: Long?)

    /**
     * Etkin antrenmanı bitirir: FinishWorkoutEvent kuyruğa eklenir ve gönderilir; [workout] hemen null olur.
     * Telefon antrenmanı etkin olmaktan çıkarır, kayıt ve setler kalır.
     */
    suspend fun finishWorkout()

    /** Bekleyen başlatmayı kuyruktan siler (telefon henüz uygulamadıysa antrenman oluşmaz). */
    suspend fun cancelPendingStart()

    /**
     * Gösterilen dinlenme sayacını [deltaSeconds] kadar uzatır ya da kısaltır (§16.2). Gösterilen sayaç yoksa
     * bir şey yapmaz; olayın `restId`'si gösterilen sayacınkidir.
     */
    suspend fun adjustRest(deltaSeconds: Int)

    /** Gösterilen dinlenme sayacını atlar (§16.2). Gösterilen sayaç yoksa bir şey yapmaz. */
    suspend fun skipRest()

    /** Varsayılan dinlenme süresi (saniye): telefondan gelen son değer; bekleyen bir ayar varsa onun değeri (iyimser). */
    val restSeconds: StateFlow<Int>

    /** Varsayılan dinlenme süresini ayarlar (15 – 600 sn aralığına sınırlanır); telefon bağlı değilse olay bekler. */
    suspend fun setRestSeconds(seconds: Int)
}

/** Bekleyen başlatma: hangi gün (null = boş antrenman) ve ekranda gösterilecek ad. */
data class PendingStart(val eventId: String, val programDayId: Long?, val dayName: String?)
