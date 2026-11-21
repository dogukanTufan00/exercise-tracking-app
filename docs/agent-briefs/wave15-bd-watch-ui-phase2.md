# Dalga 15 – Ajan BD: Saat ekranları, Faz 2 (#25)

Önce [ortak kuralları](README.md) (Kotlin bölümü) oku, sonra `docs/ARCHITECTURE.md` §15 (özellikle **§15.8**).
Aynı anda çalışanlar: BA (`lib/`, `android/`), BC (`data/`, `domain/DisplayWorkout.kt`, `domain/ProgramSchedule.kt`),
BE (`session/`, `tile/`, `WatchApp.kt`, manifest).

## Hazır olan sözleşme (DEĞİŞTİRME, kullan)

- `data/WorkoutSyncRepository.kt`: `program`, `pendingStart`, `startWorkout(dayId?)`, `cancelPendingStart()`.
- `domain/ProgramSchedule.kt`: `suggestedDay(program, today)`.
- `session/RestTimerController.kt`: dinlenme sayacı artık burada (ekrandan bağımsız, titreşimi o yapar);
  `(application as WatchApp).restTimer`.
- `session/SessionController.kt`: `requiredPermissions()`, `sync(activity, workoutActive)`.
- `LaunchActions.kt`: Tile'dan gelen Intent ekstraları.

## Dokunabileceğin dosyalar (`wear/app/src/main/.../` altında)

- `MainActivity.kt`, `ui/**` (`ui/preview/WatchPreviews.kt` hariç: onu BC günceller; derleme için gerekirse yalnızca
  önizleme çağrılarını düzelt)
- `domain/WatchFormat.kt` (gerekirse yeni biçimlendirici) + testi

## İstenenler

1. **Başlatma ekranı** (etkin antrenman yokken ana ekran):
   - Program varsa en üstte **bugünün günü** (`suggestedDay`, `LocalDate.now().dayOfWeek`): "Bugün: Push A" + "5 hareket",
     dokununca `startWorkout(dayId)`. Altında "Başka gün" listesi (programın diğer günleri), en altta **Boş antrenman**.
   - Program yoksa: **Boş antrenman** + "Telefonda program oluşturabilirsin" notu.
   - `phoneReachable == false` ise "Telefon bağlı değil" notu (mevcut davranış).
2. **Bekleme ekranı** (`pendingStart != null` ve etkin antrenman yok): gün adı (ya da "Boş antrenman"), "Başlatılıyor…",
   telefon erişilemiyorsa ya da 5 sn içinde başlamadıysa "Telefonda uygulamayı aç"; **İptal** → `cancelPendingStart()`.
   Anlık durum gelince (etkin antrenman oluşunca) kendiliğinden hareket listesine geçilir.
3. **Dinlenme sayacı** `RestTimerController`'a taşınır: `WatchWorkoutViewModel` kendi sayacını ve `RestScreen`
   titreşimini bırakır; `rest`/`finished`'i kontrolcüden okur, `startRest/adjustRest/skipRest` ona iletilir.
   Kaydırarak dinlenme ekranından çıkmak artık sayacı **durdurmaz** (sayaç arka planda sürer); hareket listesinde ve
   hareket ekranında sayaç çalışıyorsa üstte küçük "Dinlenme 0:45" satırı, dokununca dinlenme ekranı.
   `FLAG_KEEP_SCREEN_ON` kaldırılır (servis var); izin verilmediyse (servis yok) ekran açık tutma kalır.
4. **İzinler ve servis** (`MainActivity`): ilk kez etkin antrenman görüldüğünde `SessionController.requiredPermissions()`
   için `ActivityResultContracts.RequestMultiplePermissions` ile bir kez izin iste (reddedilirse tekrar sorma; tercih
   SharedPreferences'ta). Etkin antrenman durumu ya da izin her değiştiğinde `SessionController.sync(this, active)`.
5. **Tile'dan açılış** (`LaunchActions`): `onCreate` ve `onNewIntent`'te ekstraları işle: `EXTRA_START_DAY_ID` →
   `startWorkout(id)`; `EXTRA_START_EMPTY` → `startWorkout(null)`; `EXTRA_OPEN_START` → başlatma ekranı. Aynı Intent iki kez işlenmesin.
6. Renkler yalnızca `MaterialTheme.colorScheme`; yazılar Türkçe; dokunulabilir öğeler ≥ 48 dp; yuvarlak ekranda taşma yok
   (kaydırılan ekranlar `ScreenScaffold` + `TransformingLazyColumn`/`ScalingLazyColumn`, sabit ekranlar Box).

## Doğrulama

`wear/` içinde `.\gradlew.bat testDebugUnitTest --offline --console=plain` ve `assembleDebug --offline`. BC/BE'nin dosyaları yarım
olabilir; hata yalnızca onların dosyalarındaysa raporda belirt, düzeltme.
