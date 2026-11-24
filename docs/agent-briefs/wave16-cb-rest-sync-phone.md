# Dalga 16a – Ajan CB: Telefonda dinlenme sayacı ve saat senkronu (Dart) (#18, #22)

Önce [ortak kuralları](README.md) oku, sonra `docs/ARCHITECTURE.md` **§15 (tamamı) ve §16 (tamamı)**. Bu görevin özü §16.2.
Aynı anda CA (şema 4, sqlite repository, yedek, `MainActivity.kt`, `RestNotifications.kt`) ve CC (`wear/`) çalışıyor;
onların dosyalarına dokunma.

## Hazır olan sözleşme (DEĞİŞTİRME, kullan)
- `lib/data/watch/watch_protocol.dart`: `WatchRest`, `WatchSnapshot.rest`, `AddSetEvent.restSeconds`, `AdjustRestEvent`,
  `SkipRestEvent`, `SetRestSecondsEvent`, `watchRestSettingsPath`, `watchRestSecondsKey`.
- `lib/domain/rest_timer.dart`: `RestState` ve saf fonksiyonlar (bitmiş; testini sen yazacaksın).
- `WearChannel.publishRestSettings` (gerçek + `FakeWearChannel.publishedRestSeconds` hazır).
- `SettingsRepository` yeni metotları (dinlenme + yedek hatırlatması), `RestStore`, `RestNotifier` arayüzleri,
  `RestController` public imzaları. **Public imzaları değiştirme**; gövdeleri sen yazacaksın.
- `Workout.finishedAt`, `WorkoutRepository.setWorkoutFinishedAt` (`FakeWorkoutRepository`'de hazır; sqlite'ı CA yazıyor).

## Dokunabileceğin dosyalar
- `lib/data/rest/rest_store.dart` (+ `PrefsRestStore`), `lib/data/rest/rest_notifier.dart` (+ `MethodChannelRestNotifier`),
  `lib/data/rest/rest_controller.dart` (gövdeler)
- `lib/data/repositories/prefs_settings_repository.dart`, `test/fakes/fake_settings_repository.dart`
- `lib/data/watch/watch_sync_service.dart`, `lib/data/watch/watch_snapshot_builder.dart`,
  `lib/data/watch/watch_aware_workout_repository.dart`
- `lib/main.dart`
- `android/app/src/main/kotlin/com/dogukantufan00/exercise_tracking_app/WearBridge.kt` (yalnızca `publishRestSettings`)
- Yeni: `test/fakes/fake_rest_store.dart`, `test/fakes/fake_rest_notifier.dart`; `test/domain/rest_timer_test.dart`,
  `test/data/rest/rest_controller_test.dart`; `test/` altındaki saat testleri (`watch_sync_service` vb.) — yeni senaryolar ekle,
  kurucu değişikliğinin kırdığı testleri düzelt.

## 1. Ayarlar (`PrefsSettingsRepository`)
Anahtarlar: `rest_seconds` (int), `rest_vibrate_on_phone` (bool), `last_backup_at`, `backup_reminder_dismissed_at`
(ISO metin). Dinlenme okuyan metotlar önce `prefs.reload()` (ekransız motor da yazar). `getRestSeconds` her zaman
`clampRestSeconds` uygular; yoksa `restDefaultSeconds`. `FakeSettingsRepository` bellekte aynısını yapar.

## 2. `WatchSyncService`
- Kurucuya **zorunlu** `required RestStore restStore`, `required SettingsRepository settings`.
- Yeni public: `Stream<void> get restChanges` (yayın akışı; olaylar sayacı ya da ayarı değiştirdiğinde **tur sonunda bir kez**),
  `Future<void> restSettingsChanged()` (`channel.publishRestSettings(await settings.getRestSeconds())`, hata yutulur).
  `start()` sonunda bir kez `restSettingsChanged()`.
- `_republish`: antrenman `finishedAt != null` ise etkinliği temizle ve anlık durumu sil (12 saat kuralı gibi). Anlık duruma
  `rest`: store'daki sayaç bu antrenmana aitse ve `clock()`'a göre bitmemişse `WatchRest(restId, endsAt, totalSeconds)`;
  değilse `null`. (`buildWatchSnapshot`'a isteğe bağlı `WatchRest? rest` parametresi ekleyebilirsin.)
- Olaylar (§16.2):
  - `addSet` uygulandıysa: `seconds = event.restSeconds ?? await settings.getRestSeconds()`;
    `startRest(restId: event.eventId, workoutId, startedAt: event.createdAt, seconds)`; bitmemişse store'a yaz (öncekinin yerine).
  - `adjustRest`: etkin antrenmansa ve store'daki sayacın `restId`'si eşitse `adjustRest`; sonuç bitmişse store'u temizle.
  - `skipRest`: aynı koşulla store'u temizle.
  - `setRestSeconds`: `settings.setRestSeconds(clamp)`, sonra tur sonunda `restSettingsChanged()`.
  - `finishWorkout` (etkin antrenmansa): `repository.setWorkoutFinishedAt(workoutId, event.createdAt)`, etkinliği kaldır,
    sayaç bu antrenmanınsa store'u temizle.
  - Hepsinde değişiklik olduysa tur sonunda `restChanges` yay. Değişmeyen olay yine işlenmiş sayılır.
- Olayın etkilediği antrenman id'si yine `workoutUpdates`'e gider (dinlenme olayları için gerekmez).

## 3. `WatchAwareWorkoutRepository`
`setWorkoutFinishedAt`: içteki repository'ye ilet, sonra `activeWorkoutChanged()` (diğer değiştiricilerin deseni).

## 4. `RestController` (§16.2; sınıf yorumundaki kurallar bağlayıcıdır)
- `load()`: ayarları ve store'u oku; sayaç bitmişse store'u temizle; bitmemişse bitiş `Timer`'ı kur ve
  `notifier.showCountdown` çağır. `watchSync?.restChanges` dinle → yeniden oku (sayaç değiştiyse zamanlayıcı ve bildirimi
  güncelle, kalktıysa `notifier.cancel()`), `notifyListeners()`. Yeni sayaç **saatten** geldiyse de geri sayım bildirimi gösterilir.
- `start(workoutId)`: ilk çağrıda (oturum başına bir kez) `notifier.requestPermission()`; `restId = 'phone-${clock().microsecondsSinceEpoch}'`;
  store'a yaz, zamanlayıcı + `showCountdown(title: 'Dinlenme')`, `watchSync?.activeWorkoutChanged()`, bildir.
- `adjust`/`skip`/`clearForWorkout`: store + zamanlayıcı + bildirim + `activeWorkoutChanged()` + bildir.
- Bitiş zamanlayıcısı: süre dolunca store'daki sayaç hâlâ aynı `restId` ise temizle, `notifier.notifyFinished(vibrate: vibrateOnPhone)`,
  `activeWorkoutChanged()`, bildir. Zamanlayıcı `Timer(endsAt - clock())` ile kurulur (testte `fake_async` yoksa kısa süreler
  ve `clock` enjeksiyonuyla test et; `package:fake_async` pubspec'te yoksa kullanma).
- `setRestSeconds`: `settings.setRestSeconds`, `_restSeconds` güncelle, `watchSync?.restSettingsChanged()`, bildir.
- `dispose()`: zamanlayıcıyı ve aboneliği iptal et.

## 5. `MethodChannelRestNotifier`
`rest_notifier.dart` sonundaki metot tablosuna göre; `endsAt.millisecondsSinceEpoch`. Hatalar yutulur,
`requestPermission` hata/eksik eklentide `false`.

## 6. `main.dart`
- `PrefsRestStore` tek örnek; `WatchSyncService`'e `restStore` + `settings: settingsRepository` (ekransız `wearBackgroundMain` için de
  aynı şekilde `PrefsSettingsRepository()` + `PrefsRestStore()`).
- `RestController(store, settings, notifier: MethodChannelRestNotifier(), watchSync)` → `unawaited(load())`;
  `ExerciseTrackerApp`'e isteğe bağlı `RestController? restController` parametresi ekle, varsa
  `ChangeNotifierProvider<RestController>.value` ile sağla (testlerde verilmez, ekranlar `context.read` yerine
  güvenli okuma yapacak — bunu dalga 16b ele alacak).

## 7. `WearBridge.kt`
MethodChannel işleyicisine `publishRestSettings` (argüman Int): `PutDataMapRequest.create("/settings/rest")`, `dataMap.putInt("restSeconds", …)`,
`setUrgent()`; `publishTheme`'in desenini birebir izle.

## Testler (en az)
- `rest_timer_test`: başlat/sınırla, ayarla (toplam ≥ 1, bitmiş sonuç), kalan saniye yukarı yuvarlama, oran.
- `watch_sync_service`: addSet → anlık durumda `rest` (restId = eventId, endsAt = createdAt + restSeconds); `restSeconds` yok →
  ayar; geç gelen addSet → rest yok; adjust/skip eşleşen ve eşleşmeyen restId; setRestSeconds → ayar + `publishedRestSeconds`;
  finishWorkout → `finishedAt` yazıldı, anlık durum silindi; bitmiş antrenman `setActiveWorkout` ile etkin olmaz; `restChanges` yayılır.
- `rest_controller_test`: start → store + showCountdown + snapshot'ta rest; skip → cancel; bitişte `notifyFinished(vibrate: …)`
  ayara göre; restChanges ile saatten gelen sayacın yüklenmesi; ayar değişince yayın.

## Doğrulama
`flutter analyze` (tüm proje — CA'nın dosyaları yarım olabilir, yalnızca senin dosyalarındaki sorunlara bak) ve
`flutter test --timeout 60s test/domain test/data/rest test/fakes` + saat testleri.
