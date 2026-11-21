# Dalga 13 – Ajan AC: Saat uygulamasının veri katmanı (#24)

Önce [ortak kuralları](README.md) (Kotlin bölümü dahil) oku, sonra `docs/ARCHITECTURE.md` §15'in tamamını.
Aynı anda çalışan ajanlar: AA (`lib/`), AB (`android/`), AD (`wear/.../ui/`, `MainActivity.kt`). Onların dosyalarına dokunma.

## Hazır olan sözleşme (DEĞİŞTİRME, kullan)

`wear/app/src/main/java/com/dogukantufan00/exercise_tracking_app/` altında:
- `data/WatchProtocol.kt`: protokol modelleri, `ProtocolJson`, yol ve yetenek sabitleri.
- `data/WorkoutSyncRepository.kt`: arayüzün senin uygulayacağın arayüz.
- `domain/DisplayWorkout.kt`: veri sınıfları sabit; yalnızca `mergeOptimistic` gövdesini yazarsın (kurallar doc yorumunda).

## Dokunabileceğin dosyalar (`wear/app/src/` altında)

- `main/.../domain/DisplayWorkout.kt` (yalnızca `mergeOptimistic` gövdesi + private yardımcılar)
- `main/.../data/PhoneSyncRepository.kt`, `main/.../data/PendingEventStore.kt` (yeni)
- `main/.../WatchApp.kt`
- `test/java/com/dogukantufan00/exercise_tracking_app/domain/MergeOptimisticTest.kt` (yeni)
- `test/java/com/dogukantufan00/exercise_tracking_app/data/WatchProtocolTest.kt` (yeni)

## 1. `mergeOptimistic`

Doc yorumundaki kurallar. Saf Kotlin (Android import yok).

## 2. `PendingEventStore`

DataStore Preferences (`preferencesDataStore(name = "pending_events")`), tek anahtar: bekleyen olayların
`ProtocolJson` ile kodlanmış `List<WatchEvent>` JSON'u. `val events: Flow<List<WatchEvent>>`,
`suspend fun update(transform: (List<WatchEvent>) -> List<WatchEvent>)`. Bozuk veri → boş liste.

## 3. `PhoneSyncRepository(context: Context, scope: CoroutineScope) : WorkoutSyncRepository`

- **Anlık durum:** `Wearable.getDataClient(context)`. Açılışta `getDataItems(uri)` ile mevcut `/workout/active`
  DataItem'ını oku; `addListener` ile değişiklikleri dinle (`TYPE_DELETED` → `null`). JSON `DataMapItem.fromDataItem(item)
  .dataMap.getString(SNAPSHOT_JSON_KEY)`; çözülemezse ya da `protocol != WATCH_PROTOCOL_VERSION` ise yok say (öncekini koru).
  Uri: `Uri.Builder().scheme(PutDataRequest.WEAR_URI_SCHEME).path(SNAPSHOT_PATH).build()`.
- **Bekleyenleri budama:** yeni anlık durum geldiğinde (null değilse) id'si `appliedEventIds`'te olan ve `workoutId`'si
  anlık durumunkinden farklı olan olayları kuyruktan sil.
- `workout = combine(snapshot, pending) { s, p -> mergeOptimistic(s, p) }.stateIn(scope, SharingStarted.Eagerly, null)`.
- `addSet` / `deleteSet`: anlık durum yoksa hiçbir şey yapma. Olay: `UUID.randomUUID().toString()`,
  `createdAt = LocalDateTime.now().toString()`, `workoutId` = anlık durumunki. Kuyruğa ekle, sonra `flush()`.
- **Gönderim (`flush`)**: `CapabilityClient.getCapability(PHONE_CAPABILITY, FILTER_REACHABLE).await()`; düğümlerden
  `isNearby` olanı, yoksa ilkini seç; her bekleyen olayı `MessageClient.sendMessage(nodeId, EVENT_PATH, bytes).await()`.
  Hatalar yakalanır (olay kuyrukta kalır). Tekrar göndermek güvenlidir (telefon aynı id'yi bir kez uygular).
  `flush()` şu durumlarda çalışır: olay eklenince, telefon yeteneği değişince (`addListener`), ve kuyruk boş değilken
  süreç yaşadıkça her 15 saniyede bir. Aynı anda tek `flush` (`Mutex`).
- `phoneReachable`: açılışta sorgu + yetenek dinleyicisi.
- `await()` için `kotlinx-coroutines-play-services` hazır. Ağ işleri `Dispatchers.IO`.

## 4. `WatchApp`

`scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)`; `syncRepository = PhoneSyncRepository(this, scope)`.

## 5. Testler (JVM)

- `WatchProtocolTest`: ARCHITECTURE §15.4'teki örnek anlık durum JSON'u okunur (alanlar doğru); `AddSetEvent` ve
  `DeleteSetEvent` yazılınca `"type":"addSet"` / `"deleteSet"` ve tüm alan adları Dart'takilerle aynı; `target: null` okunur;
  bilinmeyen alan yok sayılır; `List<WatchEvent>` gidiş-dönüş.
- `MergeOptimisticTest`: null anlık durum; olay yokken birebir; bekleyen set sona eklenir + taslak değişir; uygulanmış
  olay yok sayılır; başka antrenmanın olayı yok sayılır; olmayan harekete set yok sayılır; silme + yeniden numaralama;
  olmayan seti silme; `hasPendingEvents`.

## Doğrulama

`wear/` içinde: `.\gradlew.bat testDebugUnitTest --offline --console=plain` ve `.\gradlew.bat assembleDebug --offline --console=plain`.
AD'nin dosyaları yarım olabilir: derleme hatası yalnızca `ui/` ya da `MainActivity.kt`'deyse raporda belirt, düzeltmeye çalışma.
