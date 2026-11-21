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
}
