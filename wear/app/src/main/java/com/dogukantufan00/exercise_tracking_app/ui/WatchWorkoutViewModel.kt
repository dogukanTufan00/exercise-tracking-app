package com.dogukantufan00.exercise_tracking_app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.dogukantufan00.exercise_tracking_app.data.PendingStart
import com.dogukantufan00.exercise_tracking_app.data.WatchProgram
import com.dogukantufan00.exercise_tracking_app.data.WatchSetValue
import com.dogukantufan00.exercise_tracking_app.data.WorkoutSyncRepository
import com.dogukantufan00.exercise_tracking_app.domain.DisplayExercise
import com.dogukantufan00.exercise_tracking_app.domain.DisplayWorkout
import com.dogukantufan00.exercise_tracking_app.domain.RestProgress
import com.dogukantufan00.exercise_tracking_app.domain.RestTimer
import com.dogukantufan00.exercise_tracking_app.domain.stepReps
import com.dogukantufan00.exercise_tracking_app.domain.stepWeight
import com.dogukantufan00.exercise_tracking_app.session.RestTimerController
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Saatteki tüm ekranların ortak durumu: antrenman ve program (repository), hareket giriş taslakları ve
 * dinlenme sayacı. Dinlenme süresi ve sayaç telefonla ortaktır: sayaç hedefi iyimser durumdan gelir ve
 * [RestTimerController] tarafından izlenir (§16.2); bu sınıf yalnızca olayları gönderir ve durumu okur.
 */
class WatchWorkoutViewModel(
    private val repository: WorkoutSyncRepository,
    private val restTimer: RestTimerController,
) : ViewModel() {

    /** Saatte gösterilen antrenman; etkin antrenman yoksa null. */
    val workout: StateFlow<DisplayWorkout?> = repository.workout

    /** Telefon şu an erişilebilir mi. */
    val phoneReachable: StateFlow<Boolean> = repository.phoneReachable

    /** Telefonun yayınladığı etkin program; yoksa null. */
    val program: StateFlow<WatchProgram?> = repository.program

    /** Telefona gönderilmiş, henüz uygulanmamış başlatma isteği; yoksa null. */
    val pendingStart: StateFlow<PendingStart?> = repository.pendingStart

    /** Varsayılan dinlenme süresi (saniye); telefonla ortak (§16.2). */
    val restSeconds: StateFlow<Int> = repository.restSeconds

    /** Kullanıcının henüz eklenmemiş set için yaptığı değişiklikler (hareket kimliğine göre). */
    private val edits = MutableStateFlow<Map<Long, WatchSetValue>>(emptyMap())
    val inputEdits: StateFlow<Map<Long, WatchSetValue>> = edits

    /** En son set eklenen hareket; dinlenme ekranı "Sıradaki" ipucunu bundan çıkarır. */
    private val lastExercise = MutableStateFlow<Long?>(null)
    val lastExerciseId: StateFlow<Long?> = lastExercise

    /** Çalışan dinlenme sayacı (kontrolcüden); yoksa null. */
    val rest: StateFlow<RestProgress?> = restTimer.rest

    /** Dinlenme kendiliğinden bittiğinde bir kez yayılır (ekran geri döner; titreşimi kontrolcü yapar). */
    val restFinished: SharedFlow<Unit> = restTimer.finished

    /** Hareketin şu an gösterilen giriş değeri: kullanıcının değişikliği, yoksa telefonun taslağı. */
    fun inputFor(exercise: DisplayExercise): WatchSetValue = edits.value[exercise.workoutExerciseId] ?: exercise.draft

    /** Ağırlığı [steps] adım değiştirir (2,5 kg adım). */
    fun adjustWeight(exerciseId: Long, steps: Int) =
        updateInput(exerciseId) { it.copy(weightKg = stepWeight(it.weightKg, steps)) }

    /** Tekrarı [steps] adım değiştirir (1 adım). */
    fun adjustReps(exerciseId: Long, steps: Int) =
        updateInput(exerciseId) { it.copy(reps = stepReps(it.reps, steps)) }

    private fun updateInput(exerciseId: Long, change: (WatchSetValue) -> WatchSetValue) {
        val base = edits.value[exerciseId] ?: findExercise(exerciseId)?.draft ?: return
        edits.update { it + (exerciseId to change(base)) }
    }

    /**
     * "Set tamam": mevcut giriş değerleriyle set ekler, değişiklik taslağı temizlenir. Dinlenme sayacı
     * iyimser olarak repository'de başlar (telefonla aynı olayla); saat ayrıca başlatmaz.
     */
    fun addSet(exerciseId: Long) {
        val exercise = findExercise(exerciseId) ?: return
        val value = edits.value[exerciseId] ?: exercise.draft
        edits.update { it - exerciseId }
        lastExercise.value = exerciseId
        viewModelScope.launch {
            repository.addSet(exerciseId, value.weightKg, value.reps)
        }
    }

    /** Telefonun onayladığı bir seti siler (bekleyen set için çağrılmaz). */
    fun deleteSet(setId: Long) {
        viewModelScope.launch { repository.deleteSet(setId) }
    }

    /** Antrenman başlatır ([programDayId] null → boş antrenman). */
    fun startWorkout(programDayId: Long?) {
        viewModelScope.launch { repository.startWorkout(programDayId) }
    }

    /**
     * Antrenmanı bitirir: iyimser durum null olur (dinlenme sayacı da hedefi kalkınca durur), saat başlatma
     * ekranına döner, telefona bitirme olayı gider.
     */
    fun finishWorkout(onFinished: () -> Unit = {}) {
        edits.value = emptyMap()
        // Olay kuyruğa yazıldıktan sonra [onFinished]: ekran (ve ViewModel) kapanırsa yazma yarıda kalmasın.
        viewModelScope.launch {
            repository.finishWorkout()
            onFinished()
        }
    }

    /** Bekleyen başlatmayı iptal eder. */
    fun cancelPendingStart() {
        viewModelScope.launch { repository.cancelPendingStart() }
    }

    /** Gösterilen dinlenme sayacını [deltaSeconds] kadar uzatır ya da kısaltır (telefona olay gider). */
    fun adjustRest(deltaSeconds: Int) {
        viewModelScope.launch { repository.adjustRest(deltaSeconds) }
    }

    /** Gösterilen dinlenme sayacını atlar ("Atla"). Ekrandan çıkmak sayacı durdurmaz. */
    fun skipRest() {
        viewModelScope.launch { repository.skipRest() }
    }

    /** Dinlenme süresi ayarını [steps] adım (15 sn) değiştirir; telefona olay olarak gider (bağlı değilse bekler). */
    fun stepRestSetting(steps: Int) {
        val seconds = RestTimer.stepSeconds(restSeconds.value, steps)
        viewModelScope.launch { repository.setRestSeconds(seconds) }
    }

    private fun findExercise(exerciseId: Long): DisplayExercise? =
        workout.value?.exercises?.firstOrNull { it.workoutExerciseId == exerciseId }
}

/** [WatchWorkoutViewModel] için fabrika; repository ve dinlenme kontrolcüsü uygulama sınıfından verilir. */
fun watchWorkoutViewModelFactory(
    repository: WorkoutSyncRepository,
    restTimer: RestTimerController,
) = viewModelFactory {
    initializer { WatchWorkoutViewModel(repository, restTimer) }
}
