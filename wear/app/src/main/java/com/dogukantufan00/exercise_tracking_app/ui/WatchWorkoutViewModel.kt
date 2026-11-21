package com.dogukantufan00.exercise_tracking_app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.dogukantufan00.exercise_tracking_app.data.PendingStart
import com.dogukantufan00.exercise_tracking_app.data.RestSettingsStore
import com.dogukantufan00.exercise_tracking_app.data.WatchProgram
import com.dogukantufan00.exercise_tracking_app.data.WatchSetValue
import com.dogukantufan00.exercise_tracking_app.data.WorkoutSyncRepository
import com.dogukantufan00.exercise_tracking_app.domain.DisplayExercise
import com.dogukantufan00.exercise_tracking_app.domain.DisplayWorkout
import com.dogukantufan00.exercise_tracking_app.domain.REST_DEFAULT_SECONDS
import com.dogukantufan00.exercise_tracking_app.domain.RestProgress
import com.dogukantufan00.exercise_tracking_app.domain.stepReps
import com.dogukantufan00.exercise_tracking_app.domain.stepWeight
import com.dogukantufan00.exercise_tracking_app.session.RestTimerController
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Saatteki tüm ekranların ortak durumu: antrenman ve program (repository), hareket giriş taslakları ve
 * dinlenme sayacı. Sayaç ekrandan bağımsızdır ve [RestTimerController] tarafından tutulur (§15.8);
 * bu sınıf yalnızca ona iletir ve durumunu okur.
 */
class WatchWorkoutViewModel(
    private val repository: WorkoutSyncRepository,
    private val restSettings: RestSettingsStore,
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

    /** Kayıtlı varsayılan dinlenme süresi (saniye). */
    val restSeconds: StateFlow<Int> = restSettings.restSeconds
        .stateIn(viewModelScope, SharingStarted.Eagerly, REST_DEFAULT_SECONDS)

    /** Kullanıcının henüz eklenmemiş set için yaptığı değişiklikler (hareket kimliğine göre). */
    private val edits = MutableStateFlow<Map<Long, WatchSetValue>>(emptyMap())
    val inputEdits: StateFlow<Map<Long, WatchSetValue>> = edits

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
     * "Set tamam": mevcut giriş değerleriyle set ekler, değişiklik taslağı temizlenir ve dinlenme sayacı başlar.
     */
    fun addSet(exerciseId: Long) {
        val exercise = findExercise(exerciseId) ?: return
        val value = edits.value[exerciseId] ?: exercise.draft
        edits.update { it - exerciseId }
        viewModelScope.launch {
            repository.addSet(exerciseId, value.weightKg, value.reps)
        }
        startRest()
    }

    /** Telefonun onayladığı bir seti siler (bekleyen set için çağrılmaz). */
    fun deleteSet(setId: Long) {
        viewModelScope.launch { repository.deleteSet(setId) }
    }

    /** Antrenman başlatır ([programDayId] null → boş antrenman). */
    fun startWorkout(programDayId: Long?) {
        viewModelScope.launch { repository.startWorkout(programDayId) }
    }

    /** Bekleyen başlatmayı iptal eder. */
    fun cancelPendingStart() {
        viewModelScope.launch { repository.cancelPendingStart() }
    }

    /** Dinlenme sayacını kayıtlı varsayılan süreyle başlatır (çalışan varsa yerine geçer). */
    fun startRest() {
        restTimer.start(restSeconds.value)
    }

    /** Sayacı [deltaSeconds] kadar uzatır ya da kısaltır (yalnızca çalışan sayaç). */
    fun adjustRest(deltaSeconds: Int) {
        restTimer.adjust(deltaSeconds)
    }

    /** Sayacı titreşimsiz durdurur ve atlar ("Atla"). Ekrandan çıkmak sayacı durdurmaz. */
    fun skipRest() {
        restTimer.skip()
    }

    /** Dinlenme süresi ayarını [steps] adım (15 sn) değiştirir ve saklar. */
    fun stepRestSetting(steps: Int) {
        viewModelScope.launch { restSettings.stepRestSeconds(steps) }
    }

    private fun findExercise(exerciseId: Long): DisplayExercise? =
        workout.value?.exercises?.firstOrNull { it.workoutExerciseId == exerciseId }
}

/** [WatchWorkoutViewModel] için fabrika; repository, ayarlar ve dinlenme kontrolcüsü uygulama sınıfından verilir. */
fun watchWorkoutViewModelFactory(
    repository: WorkoutSyncRepository,
    restSettings: RestSettingsStore,
    restTimer: RestTimerController,
) = viewModelFactory {
    initializer { WatchWorkoutViewModel(repository, restSettings, restTimer) }
}
