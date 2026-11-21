package com.dogukantufan00.exercise_tracking_app.ui

import android.os.SystemClock
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.dogukantufan00.exercise_tracking_app.data.RestSettingsStore
import com.dogukantufan00.exercise_tracking_app.data.WorkoutSyncRepository
import com.dogukantufan00.exercise_tracking_app.data.WatchSetValue
import com.dogukantufan00.exercise_tracking_app.domain.DisplayExercise
import com.dogukantufan00.exercise_tracking_app.domain.DisplayWorkout
import com.dogukantufan00.exercise_tracking_app.domain.REST_DEFAULT_SECONDS
import com.dogukantufan00.exercise_tracking_app.domain.RestCountdown
import com.dogukantufan00.exercise_tracking_app.domain.RestProgress
import com.dogukantufan00.exercise_tracking_app.domain.RestTimer
import com.dogukantufan00.exercise_tracking_app.domain.stepReps
import com.dogukantufan00.exercise_tracking_app.domain.stepWeight
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Dinlenme sayacının güncelleme aralığı (ms). */
private const val TICK_MILLIS = 200L

/**
 * Saatteki tüm ekranların ortak durumu: antrenman (repository), hareket giriş taslakları ve dinlenme sayacı.
 * Tek örnek etkinlik düzeyinde tutulur; dinlenme ekranından çıkınca da sayaç ve taslaklar kalır.
 *
 * [clock] monotonik saattir (varsayılan elapsedRealtime); testlerde sahte bir saat verilebilir.
 */
class WatchWorkoutViewModel(
    private val repository: WorkoutSyncRepository,
    private val restSettings: RestSettingsStore,
    private val clock: () -> Long = SystemClock::elapsedRealtime,
) : ViewModel() {

    /** Saatte gösterilen antrenman; etkin antrenman yoksa null. */
    val workout: StateFlow<DisplayWorkout?> = repository.workout

    /** Telefon erişilebilir mi. */
    val phoneReachable: StateFlow<Boolean> = repository.phoneReachable

    /** Kayıtlı varsayılan dinlenme süresi (saniye). */
    val restSeconds: StateFlow<Int> = restSettings.restSeconds
        .stateIn(viewModelScope, SharingStarted.Eagerly, REST_DEFAULT_SECONDS)

    /** Kullanıcının henüz eklenmemiş set için yaptığı değişiklikler (hareket kimliğine göre). */
    private val edits = MutableStateFlow<Map<Long, WatchSetValue>>(emptyMap())
    val inputEdits: StateFlow<Map<Long, WatchSetValue>> = edits

    private val countdown = MutableStateFlow<RestCountdown?>(null)
    private val nowMillis = MutableStateFlow(0L)

    /** Çalışan dinlenme sayacı; yoksa null. */
    val rest: StateFlow<RestProgress?> = combine(countdown, nowMillis) { current, now ->
        current?.let { RestTimer.progress(it, now) }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, null)

    private val restFinishedChannel = Channel<Unit>(Channel.CONFLATED)

    /** Dinlenme bittiğinde bir kez yayılır (ekran titreşim verip geri döner). */
    val restFinished: Flow<Unit> = restFinishedChannel.receiveAsFlow()

    private var tickJob: Job? = null

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

    /** Dinlenme sayacını varsayılan süreyle başlatır. */
    fun startRest() {
        val now = clock()
        val total = restSeconds.value
        restFinishedChannel.tryReceive()
        nowMillis.value = now
        countdown.value = RestTimer.start(total, now)
        tickJob?.cancel()
        tickJob = viewModelScope.launch {
            while (true) {
                val current = countdown.value ?: break
                val tick = clock()
                nowMillis.value = tick
                if (RestTimer.isFinished(current, tick)) {
                    finishRest()
                    break
                }
                delay(TICK_MILLIS)
            }
        }
    }

    /** Sayacı [deltaSeconds] kadar uzatır ya da kısaltır (yalnızca çalışan sayaç). */
    fun adjustRest(deltaSeconds: Int) {
        val current = countdown.value ?: return
        val adjusted = RestTimer.adjust(current, deltaSeconds)
        val now = clock()
        nowMillis.value = now
        if (RestTimer.isFinished(adjusted, now)) {
            finishRest()
        } else {
            countdown.value = adjusted
        }
    }

    /** Sayacı durdurur ve atlar; çıkış ya da "Atla" ile çağrılır. */
    fun skipRest() {
        tickJob?.cancel()
        tickJob = null
        countdown.value = null
        restFinishedChannel.tryReceive()
    }

    /** Dinlenme süresi ayarını [steps] adım (15 sn) değiştirir ve saklar. */
    fun stepRestSetting(steps: Int) {
        viewModelScope.launch { restSettings.stepRestSeconds(steps) }
    }

    private fun finishRest() {
        tickJob?.cancel()
        tickJob = null
        countdown.value = null
        restFinishedChannel.trySend(Unit)
    }

    private fun findExercise(exerciseId: Long): DisplayExercise? =
        workout.value?.exercises?.firstOrNull { it.workoutExerciseId == exerciseId }

    override fun onCleared() {
        tickJob?.cancel()
        super.onCleared()
    }
}

/** [WatchWorkoutViewModel] için fabrika; repository ve ayarlar uygulama sınıfından verilir. */
fun watchWorkoutViewModelFactory(
    repository: WorkoutSyncRepository,
    restSettings: RestSettingsStore,
) = viewModelFactory {
    initializer { WatchWorkoutViewModel(repository, restSettings) }
}
