# Dalga 15 – Ajan BE: Antrenman servisi, dinlenme sayacı ve Tile (#25)

Önce [ortak kuralları](README.md) (Kotlin bölümü) oku, sonra `docs/ARCHITECTURE.md` §15 (özellikle **§15.8** madde 4–5).
Aynı anda çalışanlar: BA (`lib/`, `android/`), BC (`data/`, `domain/DisplayWorkout.kt`, `domain/ProgramSchedule.kt`),
BD (`ui/`, `MainActivity.kt`).

## Hazır olan sözleşme (DEĞİŞTİRME, kullan)

- `session/RestTimerController.kt` (arayüz), `session/SessionController.kt` (iskelet; gövdeleri sen yazarsın),
  `LaunchActions.kt`, `WatchApp.restTimer` (atamasını sen yaparsın).
- `data/WorkoutSyncRepository.kt` (`workout`, `program`), `domain/ProgramSchedule.kt` (`suggestedDay`),
  `domain/RestTimer.kt` (saf sayaç hesapları; kullan).
- Bağımlılıklar `build.gradle.kts`'te hazır: `androidx.wear.tiles:tiles:1.5.0`, `protolayout(-expression, -material3):1.3.0`,
  `androidx.wear:wear-ongoing:1.0.0`, `concurrent-futures-ktx:1.2.0`. API adlarını Gradle önbelleğindeki jar/AAR'lardan
  doğrula (`C:\Users\user\.gradle\caches`), tahmin etme.

## Dokunabileceğin dosyalar (`wear/app/src/` altında)

- `main/.../session/**` (yeni dosyalar + `SessionController.kt` gövdesi), `main/.../tile/**` (yeni)
- `main/.../WatchApp.kt` (yalnızca `restTimer` ataması ve gerekirse bildirim kanalı kurulumu)
- `main/AndroidManifest.xml` (servis, Tile servisi, izinler), `main/res/**` (yeni drawable/xml/string)
- `test/java/.../session/**` (yeni)

## 1. Dinlenme sayacı (`session/SessionRestTimer.kt`)

`RestTimerController` uygulaması; `RestTimer` hesaplarını kullanır, bitiş zamanını `SystemClock.elapsedRealtime()` ile tutar,
uygulama kapsamında (`WatchApp` scope'u) çalışır. Bitince **kendisi titreştirir** (kısa-kısa-uzun:
`0,120,100,120,100,400` ms; Android 12+ `VibratorManager.defaultVibrator`) ve `finished` yayar. Saat ve titreşim
enjekte edilebilir olsun ki JVM'de test edilsin (ör. `clock: () -> Long`, `vibrate: () -> Unit`, `scope`).
Testler: başlat/bitir, ayarla (uzat/kısalt/bitir), atla (titreşim yok), yeni başlatma eskisinin yerine geçer.

## 2. Antrenman servisi (`session/WorkoutSessionService.kt`)

- Foreground service, tür `health` (manifest: `android:foregroundServiceType="health"`; izinler `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_HEALTH`, `ACTIVITY_RECOGNITION`, `POST_NOTIFICATIONS`, `VIBRATE`, `WAKE_LOCK`).
- Bildirim kanalı "Antrenman" (düşük önem); bildirim + **Ongoing Activity** (`androidx.wear.ongoing`): durum metni antrenman
  başlığı; dinlenme sürerken "Dinlenme 0:45" (sayaç durumunu dinler). Dokununca `MainActivity`.
- Sayaç sürerken partial `WakeLock` (en fazla sayaç süresi + 10 sn) ki ekran kapalıyken de bitişte titresin.
- Etkin antrenman bitince (repository `workout` null) servis kendini durdurur.
- `SessionController.requiredPermissions()` / `sync(activity, workoutActive)`: izinler verilmişse ve antrenman etkinse
  `startForegroundService`; değilse `stopService`. Çalışırken tekrar başlatmak zararsız olmalı.

## 3. Tile (`tile/WorkoutTileService.kt`)

`TileService` (`androidx.wear.tiles`), Material3 protolayout düzeni. İçerik §15.8 madde 4:
- Etkin antrenman: başlık + "N set" + **Devam et** (MainActivity, ekstra yok).
- Değilse program var ve `suggestedDay` bugün dönüyorsa: "Bugün: <gün>" + "<k> hareket" + **Başla**
  (MainActivity, `EXTRA_START_DAY_ID`).
- Değilse: **Antrenman başlat** (program varsa `EXTRA_OPEN_START`, yoksa `EXTRA_START_EMPTY`).
Veri `(application as WatchApp).syncRepository`'den (`workout.value`, `program.value`). Veri değişince
`TileService.getUpdater(context).requestUpdate(WorkoutTileService::class.java)` (WatchApp scope'unda bu iki akışı
dinleyen küçük bir yardımcı: `tile/TileUpdater.kt`, `WatchApp`'te başlatılır). Manifest: Tile servisi, önizleme görseli
(`res/drawable` basit vektör yeter), `android:label="Antrenman"`. Renkler telefonun seçili temasından:
`(application as WatchApp).themeSource.themeId.value` → ARCHITECTURE §15.7 tablosundaki primary/onPrimary/background.

## Doğrulama

`wear/` içinde `.\gradlew.bat testDebugUnitTest --offline --console=plain` ve `assembleDebug --offline`. BC/BD'nin dosyaları yarım
olabilir; hata yalnızca onların dosyalarındaysa raporda belirt, düzeltme. Bağımlılık önbellekte yoksa (`--offline` hatası)
raporda yaz; orkestratör indirir.
