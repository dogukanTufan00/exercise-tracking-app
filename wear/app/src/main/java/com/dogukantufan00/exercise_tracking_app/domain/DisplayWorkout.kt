package com.dogukantufan00.exercise_tracking_app.domain

import com.dogukantufan00.exercise_tracking_app.data.AddSetEvent
import com.dogukantufan00.exercise_tracking_app.data.AdjustRestEvent
import com.dogukantufan00.exercise_tracking_app.data.DeleteSetEvent
import com.dogukantufan00.exercise_tracking_app.data.FinishWorkoutEvent
import com.dogukantufan00.exercise_tracking_app.data.SetRestSecondsEvent
import com.dogukantufan00.exercise_tracking_app.data.SkipRestEvent
import com.dogukantufan00.exercise_tracking_app.data.StartWorkoutEvent
import com.dogukantufan00.exercise_tracking_app.data.WatchEvent
import com.dogukantufan00.exercise_tracking_app.data.WatchSetValue
import com.dogukantufan00.exercise_tracking_app.data.WatchSnapshot
import com.dogukantufan00.exercise_tracking_app.data.WatchTarget
import java.time.LocalDateTime
import kotlin.math.max

/*
 * Saatte gösterilen antrenman: telefonun son anlık durumu + henüz onaylanmamış olaylar (iyimser durum,
 * bkz. docs/ARCHITECTURE.md §15.6). Bu dosya saf Kotlin'dir: Android'i import etmez, JVM testleriyle sınanır.
 */

data class DisplayWorkout(
    val workoutId: Long,
    val title: String,
    val exercises: List<DisplayExercise>,
    /** Telefona henüz ulaşmamış (onaylanmamış) olay var mı. */
    val hasPendingEvents: Boolean,
    /** Gösterilen dinlenme sayacı (iyimser); yoksa null (§16.2). */
    val rest: DisplayRest? = null,
)

/** İyimser dinlenme sayacı. [endsAt] saat dilimsiz yerel bitiş anıdır; saat bunu sayaç hedefi olarak izler. */
data class DisplayRest(
    val restId: String,
    val endsAt: LocalDateTime,
    val totalSeconds: Int,
)

data class DisplayExercise(
    val workoutExerciseId: Long,
    val name: String,
    val target: WatchTarget?,
    val sets: List<DisplaySet>,
    /** Bir sonraki set önerisi: bekleyen set eklendiyse onun değerleri, yoksa telefonun taslağı. */
    val draft: WatchSetValue,
    val previous: List<WatchSetValue>,
)

data class DisplaySet(
    /** Telefonun verdiği id; bekleyen (henüz onaylanmamış) sette null. */
    val id: Long?,
    /** Bekleyen setin olay id'si; onaylanmış sette null. */
    val pendingEventId: String?,
    /** 1'den başlayarak sıralı (silinen setlerden sonra yeniden numaralanır). */
    val setNumber: Int,
    val weightKg: Double,
    val reps: Int,
) {
    val isPending: Boolean get() = id == null
}

/**
 * Anlık durum ile bekleyen olayları birleştirir.
 *
 * Kurallar:
 * - [snapshot] null ise null.
 * - Id'si `appliedEventIds`'te OLMAYAN olaylar uygulanır, [pending] sırasıyla.
 * - AddSetEvent: `workoutId`'si anlık durumunkiyle aynıysa ilgili hareketin sonuna bekleyen set eklenir; hareketin
 *   taslağı bu setin değerleri olur. Hareket anlık durumda yoksa olay yok sayılır. `restSeconds` varsa sayaç
 *   restId = eventId, endsAt = createdAt + süre olarak başlar (süre 15 sn – 10 dk aralığına sınırlanır).
 * - DeleteSetEvent: `workoutId` aynıysa o id'li onaylı set listeden çıkarılır; set yoksa yok sayılır.
 * - AdjustRestEvent: `workoutId` ve `restId` gösterilen sayaçla aynıysa endsAt delta kadar kayar,
 *   totalSeconds en az 1 olur.
 * - SkipRestEvent: `workoutId` ve `restId` aynıysa sayaç kalkar (rest = null).
 * - SetRestSecondsEvent: sayacı etkilemez; yalnızca bekleyen olay sayılır.
 * - StartWorkoutEvent: iyimser durumu değiştirmez (§15.8); antrenman telefonda oluşunca anlık durumda görünür.
 * - FinishWorkoutEvent: `workoutId` anlık durumunkiyle aynıysa sonuç null olur (antrenman saatte hemen kapanır).
 * - Her hareketin setleri sonunda 1, 2, 3… olarak numaralanır.
 * - [DisplayWorkout.hasPendingEvents]: uygulanan bir set, sayaç ya da ayar olayı varsa true.
 */
fun mergeOptimistic(snapshot: WatchSnapshot?, pending: List<WatchEvent>): DisplayWorkout? {
    if (snapshot == null) return null

    val applied = snapshot.appliedEventIds.toSet()
    val events = pending.filter { it.eventId !in applied }
    // Bu antrenmanı bitirme isteği bekliyorsa saat onu hemen kapatır (telefon uygulayınca anlık durum zaten silinir).
    if (events.any { it is FinishWorkoutEvent && it.workoutId == snapshot.workoutId }) return null

    val setsByExercise = mutableMapOf<Long, MutableList<DisplaySet>>()
    val drafts = mutableMapOf<Long, WatchSetValue>()
    for (exercise in snapshot.exercises) {
        setsByExercise[exercise.workoutExerciseId] = exercise.sets.map { set ->
            DisplaySet(
                id = set.id,
                pendingEventId = null,
                setNumber = set.setNumber,
                weightKg = set.weightKg,
                reps = set.reps,
            )
        }.toMutableList()
        drafts[exercise.workoutExerciseId] = exercise.draft
    }

    var rest: DisplayRest? = snapshot.rest?.let {
        DisplayRest(restId = it.restId, endsAt = LocalDateTime.parse(it.endsAt), totalSeconds = it.totalSeconds)
    }
    var hasPendingEvents = false
    for (event in events) {
        when (event) {
            is AddSetEvent -> {
                val sets = setsByExercise[event.workoutExerciseId]
                if (event.workoutId == snapshot.workoutId && sets != null && isValidSetValue(event.weightKg, event.reps)) {
                    sets.add(
                        DisplaySet(
                            id = null,
                            pendingEventId = event.eventId,
                            setNumber = 0,
                            weightKg = event.weightKg,
                            reps = event.reps,
                        ),
                    )
                    drafts[event.workoutExerciseId] = WatchSetValue(event.weightKg, event.reps)
                    event.restSeconds?.let { seconds ->
                        val total = RestTimer.clampSeconds(seconds)
                        rest = DisplayRest(
                            restId = event.eventId,
                            endsAt = LocalDateTime.parse(event.createdAt).plusSeconds(total.toLong()),
                            totalSeconds = total,
                        )
                    }
                    hasPendingEvents = true
                }
            }
            is DeleteSetEvent -> {
                val owner = setsByExercise.values.firstOrNull { sets -> sets.any { it.id == event.setId } }
                if (event.workoutId == snapshot.workoutId && owner != null) {
                    owner.removeAll { it.id == event.setId }
                    hasPendingEvents = true
                }
            }
            is AdjustRestEvent -> {
                val current = rest
                if (event.workoutId == snapshot.workoutId && current != null && current.restId == event.restId) {
                    rest = current.copy(
                        endsAt = current.endsAt.plusSeconds(event.deltaSeconds.toLong()),
                        totalSeconds = max(1, current.totalSeconds + event.deltaSeconds),
                    )
                    hasPendingEvents = true
                }
            }
            is SkipRestEvent -> {
                val current = rest
                if (event.workoutId == snapshot.workoutId && current != null && current.restId == event.restId) {
                    rest = null
                    hasPendingEvents = true
                }
            }
            is SetRestSecondsEvent -> hasPendingEvents = true
            is StartWorkoutEvent, is FinishWorkoutEvent -> Unit
        }
    }

    return DisplayWorkout(
        workoutId = snapshot.workoutId,
        title = snapshot.title,
        exercises = snapshot.exercises.map { exercise ->
            DisplayExercise(
                workoutExerciseId = exercise.workoutExerciseId,
                name = exercise.name,
                target = exercise.target,
                sets = renumber(setsByExercise.getValue(exercise.workoutExerciseId)),
                draft = drafts.getValue(exercise.workoutExerciseId),
                previous = exercise.previous,
            )
        },
        hasPendingEvents = hasPendingEvents,
        rest = rest,
    )
}

/** Set değerleri geçerli mi (ağırlık negatif değil, tekrar pozitif); geçersiz olay yok sayılır. */
private fun isValidSetValue(weightKg: Double, reps: Int): Boolean = weightKg >= 0.0 && reps > 0

/** Setleri 1'den başlayarak yeniden numaralar. */
private fun renumber(sets: List<DisplaySet>): List<DisplaySet> =
    sets.mapIndexed { index, set -> set.copy(setNumber = index + 1) }
