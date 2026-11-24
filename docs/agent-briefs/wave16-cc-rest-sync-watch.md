# Dalga 16a – Ajan CC: Saatte senkron dinlenme sayacı (Kotlin) (#18)

Önce [ortak kuralları](README.md) (**Kotlin bölümü**) oku, sonra `docs/ARCHITECTURE.md` **§15 (tamamı) ve §16.2**.
Dart karşılığı hazır: `lib/data/watch/watch_protocol.dart` (yalnızca oku). Yalnızca `wear/` içinde çalış; aynı anda
iki ajan telefon tarafında çalışıyor.

## Amaç
Dinlenme sayacı artık saatte yerel değil; telefonla ortak. Saatte gösterilen sayaç = telefonun anlık durumundaki
`rest` + saatin bekleyen olayları (iyimser durum). Süre ayarı telefondan (`/settings/rest`) gelir.

## Dokunabileceğin dosyalar (`wear/app/src/main/java/com/dogukantufan00/exercise_tracking_app/` altında)
- `data/WatchProtocol.kt`, `data/PhoneSyncRepository.kt`, `data/WorkoutSyncRepository.kt`, `data/RestSettingsStore.kt`
  (sil ya da önbelleğe dönüştür)
- `domain/DisplayWorkout.kt`, `domain/RestTimer.kt`
- `session/RestTimerController.kt`, `session/SessionRestTimer.kt`
- `ui/WatchWorkoutViewModel.kt`, `ui/screens/RestScreen.kt`, `ui/screens/RestSettingsScreen.kt`, `ui/preview/WatchPreviews.kt`
- `WatchApp.kt` (bağlama)
- `wear/app/src/test/...` altındaki testler (güncelle + yenilerini ekle)

## 1. Protokol (`WatchProtocol.kt`, Dart ile birebir)
- `REST_SETTINGS_PATH = "/settings/rest"`, `REST_SECONDS_KEY = "restSeconds"` (DataMap'te Int).
- `@Serializable data class WatchRest(val restId: String, val endsAt: String, val totalSeconds: Int)`.
- `WatchSnapshot`'a `val rest: WatchRest? = null` (eski telefon göndermezse null).
- `AddSetEvent`'e `val restSeconds: Int? = null`.
- Yeni olaylar: `@SerialName("adjustRest") AdjustRestEvent(protocol, eventId, workoutId: Long, createdAt, restId: String, deltaSeconds: Int)`,
  `@SerialName("skipRest") SkipRestEvent(protocol, eventId, workoutId, createdAt, restId)`,
  `@SerialName("setRestSeconds") SetRestSecondsEvent(protocol, eventId, createdAt, seconds: Int)`.
  Alan sırası ve adları Dart'taki `toJson` ile aynı.
- `WatchProtocolTest`: yeni alanların gidiş-dönüşü, `rest` alanı olmayan eski anlık durumun okunması, Dart'ın ürettiği örnek JSON'lar.

## 2. İyimser durum (`DisplayWorkout.kt`, saf Kotlin)
- `data class DisplayRest(val restId: String, val endsAt: LocalDateTime, val totalSeconds: Int)`; `DisplayWorkout`'a `val rest: DisplayRest?`.
- `mergeOptimistic`: başlangıç `snapshot.rest` (endsAt `LocalDateTime.parse`). Uygulanmamış bekleyen olaylar sırayla:
  - geçerli `AddSetEvent` (aynı antrenman, hareket var): `restSeconds` null değilse
    `DisplayRest(restId = eventId, endsAt = createdAt + clamp(restSeconds), totalSeconds = clamp(restSeconds))`;
  - `AdjustRestEvent` (aynı antrenman, `restId` eşit): `endsAt += delta`, `totalSeconds = max(1, total + delta)`;
  - `SkipRestEvent` (aynı antrenman, `restId` eşit): `rest = null`;
  - `SetRestSecondsEvent`: dinlenmeyi etkilemez. Bunlar `hasPendingEvents`'i true yapar (sayaç olayları da).
- `MergeOptimisticTest`'e bu kuralların testleri.

## 3. Depo (`WorkoutSyncRepository` / `PhoneSyncRepository`)
- `addSet(workoutExerciseId, weightKg, reps)`: olaya `restSeconds = restSeconds.value` koyar.
- Yeni: `suspend fun adjustRest(deltaSeconds: Int)`, `suspend fun skipRest()` (o an gösterilen `workout.value?.rest` yoksa bir şey yapmaz;
  olay `restId`'si gösterilen sayacınki), `val restSeconds: StateFlow<Int>`, `suspend fun setRestSeconds(seconds: Int)`.
- `restSeconds`: `/settings/rest` DataItem'ını okur ve dinler (temanın `ThemeSource` desenine bak), son değeri saatin
  SharedPreferences/DataStore'unda saklar (açılışta önce onu kullanır; hiç yoksa 90). Bekleyen `SetRestSecondsEvent` varsa
  sonuncusunun değeri gösterilir (iyimser).
- Olaylar mevcut kuyruk/yeniden gönderme düzeniyle gider (§15.6); `appliedEventIds` ile temizlenir.

## 4. Sayaç hedefi izler (`RestTimerController`, `SessionRestTimer`)
- Arayüz: `start/adjust/skip` yerine `fun follow(target: DisplayRest?)`; `rest: StateFlow<RestProgress?>` ve `finished: SharedFlow<Unit>` kalır
  (servis ve Tile bunları kullanıyor; imzaları değiştirme). `RestProgress`'e `restId` eklemek gerekmez.
- `follow`: hedef aynıysa (eşit `DisplayRest`) bir şey yapma. Yeni/değişmiş hedef → bitiş anını monotonik saate çevir:
  `endElapsed = elapsedNow + (endsAtEpochMs - wallNowMs)` (`endsAt` yerel saattir: `atZone(ZoneId.systemDefault())`).
  Saatler (`elapsed`, `wall`) ve titreşim enjekte edilir (JVM testi için). Hedef null → titreşimsiz dur.
- **Titreşim kuralı:** bir `restId` için en fazla bir kez ve yalnızca sayaç izlenirken kalan süre > 0 görüldüyse
  (eski/bitmiş bir hedef gelirse titreme). Aynı `restId` ±15 ile değişirse devam eder, yeniden başlamış sayılmaz.
- `WatchApp`: uygulama kapsamında `syncRepository.workout.map { it?.rest }.distinctUntilChanged()` toplanır ve `restTimer.follow(...)`'a verilir
  (ekran kapalıyken de çalışsın; servis bunu zaten canlı tutar).
- `SessionRestTimerTest`'i yeni davranışa göre yeniden yaz: izleme, değişen hedef, null hedef, tek titreşim, bitmiş hedefte titrememe.

## 5. ViewModel ve ekranlar
- `WatchWorkoutViewModel`: `addSet` artık `startRest()` çağırmaz (iyimser durum sayacı başlatır); `adjustRest`/`skipRest` depoya gider;
  `restSeconds` depodan; `stepRestSetting(steps)` → `repository.setRestSeconds(RestTimer.stepSeconds(current, steps))`.
  `finishWorkout` içindeki `restTimer.skip()` kaldırılır (bitirme iyimser durumu null yapar → hedef null).
- `RestScreen`: sayaç kalkarsa (telefonda atlandı/bitti) `onDone()` ile geri dön; mevcut `finished` dinlemesi kalır.
- `RestSettingsScreen`: değer depodan; telefona bağlı değilken de değiştirilebilir (olay bekler).
- Önizlemeler derlenmeli (sahte depo varsa güncelle).

## Doğrulama
`wear/` içinde `.\gradlew.bat testDebugUnitTest --offline --console=plain` ve `.\gradlew.bat assembleDebug --offline --console=plain`
→ "BUILD SUCCESSFUL".
