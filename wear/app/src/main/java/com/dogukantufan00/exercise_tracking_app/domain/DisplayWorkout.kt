package com.dogukantufan00.exercise_tracking_app.domain

import com.dogukantufan00.exercise_tracking_app.data.AddSetEvent
import com.dogukantufan00.exercise_tracking_app.data.DeleteSetEvent
import com.dogukantufan00.exercise_tracking_app.data.FinishWorkoutEvent
import com.dogukantufan00.exercise_tracking_app.data.StartWorkoutEvent
import com.dogukantufan00.exercise_tracking_app.data.WatchEvent
import com.dogukantufan00.exercise_tracking_app.data.WatchSetValue
import com.dogukantufan00.exercise_tracking_app.data.WatchSnapshot
import com.dogukantufan00.exercise_tracking_app.data.WatchTarget

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
 *   taslağı bu setin değerleri olur. Hareket anlık durumda yoksa olay yok sayılır.
 * - DeleteSetEvent: `workoutId` aynıysa o id'li onaylı set listeden çıkarılır; set yoksa yok sayılır.
 * - StartWorkoutEvent: iyimser durumu değiştirmez (§15.8); antrenman telefonda oluşunca anlık durumda görünür.
 * - FinishWorkoutEvent: `workoutId` anlık durumunkiyle aynıysa sonuç null olur (antrenman saatte hemen kapanır).
 * - Her hareketin setleri sonunda 1, 2, 3… olarak numaralanır.
 * - [DisplayWorkout.hasPendingEvents]: en az bir olay uygulandıysa true.
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
    )
}

/** Set değerleri geçerli mi (ağırlık negatif değil, tekrar pozitif); geçersiz olay yok sayılır. */
private fun isValidSetValue(weightKg: Double, reps: Int): Boolean = weightKg >= 0.0 && reps > 0

/** Setleri 1'den başlayarak yeniden numaralar. */
private fun renumber(sets: List<DisplaySet>): List<DisplaySet> =
    sets.mapIndexed { index, set -> set.copy(setNumber = index + 1) }
