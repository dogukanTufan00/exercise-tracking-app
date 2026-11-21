package com.dogukantufan00.exercise_tracking_app.domain

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
 * - Yalnızca `workoutId`'si anlık durumunkiyle aynı ve id'si `appliedEventIds`'te OLMAYAN olaylar uygulanır,
 *   [pending] sırasıyla.
 * - AddSetEvent: ilgili hareketin sonuna bekleyen set eklenir; hareketin taslağı bu setin değerleri olur.
 *   Hareket anlık durumda yoksa olay yok sayılır.
 * - DeleteSetEvent: o id'li onaylı set listeden çıkarılır; set yoksa yok sayılır.
 * - Her hareketin setleri sonunda 1, 2, 3… olarak numaralanır.
 * - [DisplayWorkout.hasPendingEvents]: en az bir olay uygulandıysa true.
 */
fun mergeOptimistic(snapshot: WatchSnapshot?, pending: List<WatchEvent>): DisplayWorkout? {
    TODO("Ajan AC uygular")
}
