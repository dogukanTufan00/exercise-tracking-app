package com.dogukantufan00.exercise_tracking_app.domain

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToLong

/*
 * Saatte gösterilen biçimler ve değer sınırları. Saf Kotlin: Android import etmez, JVM testlidir.
 * Ağırlıklar negatif olmaz; tekrar en az 1'dir (bkz. docs/agent-briefs/wave13-ad-watch-ui.md).
 */

/** Ağırlık düğmesinin adımı (kg). */
const val WEIGHT_STEP_KG = 2.5

/** Tekrar düğmesinin adımı. */
const val REPS_STEP = 1

/** Ağırlığı Türkçe ondalık virgülle yazar: 37.5 → "37,5", 40.0 → "40". Ağırlık negatif olmamalıdır. */
fun formatWeight(weightKg: Double): String {
    val tenths = (weightKg * 10).roundToLong()
    val whole = tenths / 10
    val fraction = abs(tenths % 10)
    return if (fraction == 0L) whole.toString() else "$whole,$fraction"
}

/** Bir set: "40 × 10". */
fun formatSet(weightKg: Double, reps: Int): String = "${formatWeight(weightKg)} × $reps"

/** Hareket hedefi: "Hedef 3 × 10 · 40 kg", ağırlık yoksa "Hedef 3 × 10". */
fun formatTarget(sets: Int, reps: Int, weightKg: Double?): String {
    val base = "Hedef $sets × $reps"
    return if (weightKg == null) base else "$base · ${formatWeight(weightKg)} kg"
}

/** "Geçen sefer" seti: "Geçen: 37,5 × 10". */
fun formatPrevious(weightKg: Double, reps: Int): String = "Geçen: ${formatSet(weightKg, reps)}"

/** Hareket ilerlemesi: hedef varsa "2/3 set", yoksa "2 set". */
fun formatSetProgress(doneSets: Int, targetSets: Int?): String =
    if (targetSets == null) "$doneSets set" else "$doneSets/$targetSets set"

/** Saniyeyi "m:ss" biçimine çevirir: 65 → "1:05". Negatif değerler 0 sayılır. */
fun formatDuration(totalSeconds: Int): String {
    val seconds = max(0, totalSeconds)
    return "${seconds / 60}:${(seconds % 60).toString().padStart(2, '0')}"
}

/** Ağırlığı [steps] adım kadar değiştirir (her adım [WEIGHT_STEP_KG]); sonuç en az 0. */
fun stepWeight(weightKg: Double, steps: Int): Double = max(0.0, weightKg + steps * WEIGHT_STEP_KG)

/** Tekrarı [steps] adım kadar değiştirir; sonuç en az 1. */
fun stepReps(reps: Int, steps: Int): Int = max(1, reps + steps * REPS_STEP)
