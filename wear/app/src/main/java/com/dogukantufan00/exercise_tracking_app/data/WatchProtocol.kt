package com.dogukantufan00.exercise_tracking_app.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/*
 * Saat ile telefon arasındaki protokolün (sürüm 1) Kotlin modelleri (bkz. docs/ARCHITECTURE.md §15.4).
 * Dart karşılığı: lib/data/watch/watch_protocol.dart. İki dosya birebir aynı JSON'u üretmeli ve okumalıdır.
 * Kimlikler Dart'taki int'e karşılık Long'dur.
 */

/** Protokol sürümü. Farklı sürümdeki olay ve anlık durumlar yok sayılır. */
const val WATCH_PROTOCOL_VERSION = 1

/** Anlık durumun yayınlandığı DataItem yolu; JSON, DataMap'te [SNAPSHOT_JSON_KEY] anahtarındadır. */
const val SNAPSHOT_PATH = "/workout/active"
const val SNAPSHOT_JSON_KEY = "json"

/**
 * Telefonda seçili temanın DataItem yolu; tema adı [THEME_KEY] anahtarında metin olarak durur
 * (`darkOrange`, `redBlack`, `yellowNavy`, `lightBlue`; bilinmeyen değer → varsayılan tema).
 */
const val THEME_PATH = "/settings/theme"
const val THEME_KEY = "themeId"

/**
 * Dinlenme süresi ayarının DataItem yolu (§16.2); süre (saniye, int) DataMap'te [REST_SECONDS_KEY] anahtarındadır.
 * Telefon her değişiklikte yazar; saat son değeri saklar ve bağlantı yokken onu kullanır.
 */
const val REST_SETTINGS_PATH = "/settings/rest"
const val REST_SECONDS_KEY = "restSeconds"

/** Etkin programın DataItem yolu; JSON, DataMap'te [SNAPSHOT_JSON_KEY] ("json") anahtarındadır (§15.8). */
const val PROGRAM_PATH = "/program/active"

/**
 * İşlenmiş olay id'lerinin her zaman yayınlandığı DataItem yolu (§15.8): JSON [WatchApplied], "json" anahtarında.
 * Etkin antrenman olmasa da yazılır; bekleyen olaylar hem bununla hem anlık durumdakiyle temizlenir.
 */
const val APPLIED_PATH = "/events/applied"

/** Saatin olay gönderdiği mesaj yolu. */
const val EVENT_PATH = "/event"

/** Data Layer yetenekleri (res/values/wear.xml). */
const val PHONE_CAPABILITY = "exercise_tracker_phone"
const val WATCH_CAPABILITY = "exercise_tracker_watch"

/** Protokolün tek JSON yapılandırması: olay türü `type` alanında, bilinmeyen alanlar yok sayılır. */
val ProtocolJson: Json = Json {
    classDiscriminator = "type"
    ignoreUnknownKeys = true
    encodeDefaults = true
    explicitNulls = true
}

@Serializable
data class WatchSetValue(val weightKg: Double, val reps: Int)

@Serializable
data class WatchTarget(val sets: Int, val reps: Int, val weightKg: Double?)

/** Telefonda kayıtlı bir set. */
@Serializable
data class WatchSet(val id: Long, val setNumber: Int, val weightKg: Double, val reps: Int)

/**
 * Çalışan dinlenme sayacı (§16.2). [endsAt] saat dilimsiz yerel bitiş anıdır; iki cihaz kalan süreyi
 * kendi saatinden hesaplar. [totalSeconds] ±15 sn ile değişir (ilerleme halkası için).
 */
@Serializable
data class WatchRest(val restId: String, val endsAt: String, val totalSeconds: Int)

@Serializable
data class WatchExercise(
    val workoutExerciseId: Long,
    val name: String,
    val target: WatchTarget?,
    val sets: List<WatchSet>,
    /** Telefonun önerdiği bir sonraki set. */
    val draft: WatchSetValue,
    /** "Geçen sefer" setleri; boş olabilir. */
    val previous: List<WatchSetValue>,
)

/** Telefonun yayınladığı anlık durum. */
@Serializable
data class WatchSnapshot(
    val protocol: Int = WATCH_PROTOCOL_VERSION,
    val workoutId: Long,
    /** Antrenman başlığı; yoksa telefonun gösterdiği tarih metni. */
    val title: String,
    /** Saat dilimsiz ISO 8601 yerel saat; saat yalnızca gösterir, hesap yapmaz. */
    val startedAt: String,
    /** Telefonun işlediği son en fazla 50 olayın id'si. */
    val appliedEventIds: List<String>,
    /** position sırasıyla. */
    val exercises: List<WatchExercise>,
    /** Çalışan dinlenme sayacı; yoksa ya da eski telefon göndermediyse null. */
    val rest: WatchRest? = null,
)

/** Saatten telefona giden olay. JSON'daki `type` alanı alt sınıfı belirler. */
@Serializable
sealed class WatchEvent {
    abstract val protocol: Int
    abstract val eventId: String

    /** Saat dilimsiz ISO 8601 yerel saat (ör. LocalDateTime.now().toString()). */
    abstract val createdAt: String
}

/**
 * Saatte "Set tamam" denildi. [restSeconds]: saatin bu set için başlattığı dinlenme süresi; eski saat
 * sürümleri göndermez (null), telefon kendi ayarını kullanır.
 */
@Serializable
@SerialName("addSet")
data class AddSetEvent(
    override val protocol: Int = WATCH_PROTOCOL_VERSION,
    override val eventId: String,
    val workoutId: Long,
    override val createdAt: String,
    val workoutExerciseId: Long,
    val weightKg: Double,
    val reps: Int,
    val restSeconds: Int? = null,
) : WatchEvent()

/** Telefonun onayladığı bir set silindi. */
@Serializable
@SerialName("deleteSet")
data class DeleteSetEvent(
    override val protocol: Int = WATCH_PROTOCOL_VERSION,
    override val eventId: String,
    val workoutId: Long,
    override val createdAt: String,
    val setId: Long,
) : WatchEvent()

/** Saatten antrenman başlatıldı (§15.8); [programDayId] null ise boş antrenman. Olayda workoutId yoktur. */
@Serializable
@SerialName("startWorkout")
data class StartWorkoutEvent(
    override val protocol: Int = WATCH_PROTOCOL_VERSION,
    override val eventId: String,
    override val createdAt: String,
    val programDayId: Long?,
) : WatchEvent()

/** Saatten antrenman bitirildi: telefon antrenmanı etkin olmaktan çıkarır; kayıt ve setler kalır. */
@Serializable
@SerialName("finishWorkout")
data class FinishWorkoutEvent(
    override val protocol: Int = WATCH_PROTOCOL_VERSION,
    override val eventId: String,
    val workoutId: Long,
    override val createdAt: String,
) : WatchEvent()

/** Saatte çalışan dinlenme ±[deltaSeconds] değiştirildi; yalnızca [restId] telefondaki sayaçsa uygulanır (§16.2). */
@Serializable
@SerialName("adjustRest")
data class AdjustRestEvent(
    override val protocol: Int = WATCH_PROTOCOL_VERSION,
    override val eventId: String,
    val workoutId: Long,
    override val createdAt: String,
    val restId: String,
    val deltaSeconds: Int,
) : WatchEvent()

/** Saatte dinlenme atlandı; yalnızca [restId] telefondaki sayaçsa uygulanır (§16.2). */
@Serializable
@SerialName("skipRest")
data class SkipRestEvent(
    override val protocol: Int = WATCH_PROTOCOL_VERSION,
    override val eventId: String,
    val workoutId: Long,
    override val createdAt: String,
    val restId: String,
) : WatchEvent()

/** Saatin ayar ekranında varsayılan dinlenme süresi değişti (§16.2); etkin antrenman gerekmez. */
@Serializable
@SerialName("setRestSeconds")
data class SetRestSecondsEvent(
    override val protocol: Int = WATCH_PROTOCOL_VERSION,
    override val eventId: String,
    override val createdAt: String,
    val seconds: Int,
) : WatchEvent()

@Serializable
data class WatchApplied(val protocol: Int = WATCH_PROTOCOL_VERSION, val appliedEventIds: List<String>)

/** Etkin programın bir günü. [weekday]: 1 = Pazartesi … 7 = Pazar, null = güne bağlı değil. */
@Serializable
data class WatchProgramDay(
    val dayId: Long,
    val name: String,
    val weekday: Int?,
    /** Hareket adları, sırasıyla. */
    val exercises: List<String>,
)

/** Telefonun `/program/active`'e yayınladığı etkin program. */
@Serializable
data class WatchProgram(
    val protocol: Int = WATCH_PROTOCOL_VERSION,
    val programId: Long,
    val name: String,
    /** position sırasıyla. */
    val days: List<WatchProgramDay>,
)
