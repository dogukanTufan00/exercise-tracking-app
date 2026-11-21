# Dalga 13 – Ajan AB: Telefonun Kotlin köprüsü (#24)

Önce [ortak kuralları](README.md) (Kotlin bölümü dahil) oku, sonra `docs/ARCHITECTURE.md` §15'in tamamını.
Dart tarafındaki karşılık: `lib/data/watch/wear_channel.dart` (kanal ve metot adları oradaki doc yorumunda; OKU, değiştirme).
Aynı anda çalışan ajanlar: AA (`lib/`, `test/`), AC/AD (`wear/`). Onların dosyalarına dokunma.

## Dokunabileceğin dosyalar (hepsi `android/app/` altında)

- `build.gradle.kts` (yalnızca `dependencies { }` bloğu ekle)
- `src/main/AndroidManifest.xml` (yalnızca servis tanımı ekle)
- `src/main/res/values/wear.xml` (yeni)
- `src/main/kotlin/com/dogukantufan00/exercise_tracking_app/MainActivity.kt`
- aynı paket: `WearEventQueue.kt`, `WearEventNotifier.kt`, `PhoneWearListenerService.kt` (yeni)

## İstenenler

1. **Bağımlılık:** `implementation("com.google.android.gms:play-services-wearable:19.0.0")`.
2. **`wear.xml`:** `android_wear_capabilities` dizisinde `exercise_tracker_phone` (saat tarafındaki
   `wear/app/src/main/res/values/wear.xml` örneğini oku).
3. **`WearEventQueue`** (`object` ya da `Context` alan sınıf): SharedPreferences (`wear_event_queue`) içinde ham olay
   JSON'larının dizisi. `add(json)`: `org.json.JSONObject` ile `eventId` metnini oku; yoksa ya da JSON bozuksa **ekleme**;
   aynı `eventId` zaten kuyruktaysa ekleme; en fazla 500 kayıt (taşarsa en eskiyi at). `list(): List<String>`,
   `ack(ids)`: o id'lileri sil. Tüm metotlar `@Synchronized` (servis ve etkinlik aynı anda erişebilir).
4. **`PhoneWearListenerService : WearableListenerService`**: `onMessageReceived` yol `/event` ise
   `WearEventQueue.add(String(data, UTF_8))`, sonra `WearEventNotifier.notifyAvailable()`.
   Manifest: `exported="true"`, intent-filter `com.google.android.gms.wearable.MESSAGE_RECEIVED`,
   `<data android:scheme="wear" android:host="*" android:pathPrefix="/event" />`.
5. **`WearEventNotifier`** (`object`): Flutter'ın `EventChannel.EventSink`'ini tutar (`null` olabilir);
   `notifyAvailable()` ana iş parçacığında (`Handler(Looper.getMainLooper())`) `sink?.success(null)` çağırır.
6. **`MainActivity.configureFlutterEngine`**: `MethodChannel("exercise_tracker/wear")`:
   - `publishSnapshot(String json)`: `PutDataMapRequest.create("/workout/active")`, `dataMap.putString("json", json)`,
     `setUrgent()`, `Wearable.getDataClient(this).putDataItem(...)`.
   - `clearSnapshot`: `deleteDataItems(Uri.Builder().scheme(PutDataRequest.WEAR_URI_SCHEME).path("/workout/active").build())`.
   - `drainEvents` → `WearEventQueue.list()`; `ackEvents(List<String>)` → `WearEventQueue.ack`.
   - Bilinmeyen metot → `result.notImplemented()`.
   - **Hata yok:** Play Services/saat yoksa görevlerin hatası yalnızca `Log.w` ile yazılır, `result.success(null)` döner.
     `result` görev tamamlanmasını beklemeden hemen `success` olabilir (yayın "ateşle ve unut").
   `EventChannel("exercise_tracker/wear/events")`: `onListen` → `WearEventNotifier.sink = events`, `onCancel` → `null`.
7. Kodda kısa Türkçe doc yorumları (projedeki diğer dosyalar gibi).

## Doğrulama

- Proje kökünde: `& 'C:\dev\flutter\bin\flutter.bat' build apk --debug` → "Built build\app\outputs\…app-debug.apk".
  Derleme sandbox nedeniyle ağ/dosya hatası verirse (Kotlin derleme hatası değilse) raporda aynen yaz; derlemeyi orkestratör
  kullanıcının terminalinde tekrarlar.
- `flutter analyze` / `flutter test` çalıştırman gerekmez (Dart dosyasına dokunmuyorsun).
