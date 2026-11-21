# Dalga 13 – Ajan AD: Saat uygulamasının ekranları (#24)

Önce [ortak kuralları](README.md) (Kotlin bölümü dahil) oku, sonra `docs/ARCHITECTURE.md` §15'in tamamını (özellikle §15.6).
Aynı anda çalışan ajanlar: AA (`lib/`), AB (`android/`), AC (`wear/.../data/`, `domain/DisplayWorkout.kt`, `WatchApp.kt`).
Onların dosyalarına dokunma.

## Hazır olan sözleşme (DEĞİŞTİRME, kullan)

`wear/app/src/main/java/com/dogukantufan00/exercise_tracking_app/` altında:
- `data/WorkoutSyncRepository.kt` — veriye tek giriş; `workout: StateFlow<DisplayWorkout?>`, `phoneReachable`, `addSet`, `deleteSet`.
- `domain/DisplayWorkout.kt` — gösterilecek modeller (`DisplayWorkout`, `DisplayExercise`, `DisplaySet`).
- `data/WatchProtocol.kt` — `WatchSetValue`, `WatchTarget`.
- `WatchApp.kt` — `(application as WatchApp).syncRepository`.

## Dokunabileceğin dosyalar (`wear/app/src/` altında)

- `main/.../MainActivity.kt`
- `main/.../ui/**` (yeni: tema, ViewModel, ekranlar, gezinme, önizleme için sahte repository)
- `main/.../data/RestSettingsStore.kt` (yeni)
- `main/.../domain/WatchFormat.kt`, `main/.../domain/RestTimer.kt` (yeni, saf Kotlin)
- `test/java/com/dogukantufan00/exercise_tracking_app/domain/WatchFormatTest.kt`, `RestTimerTest.kt` (yeni)
- `main/res/values/strings.xml` (gerekirse metin ekle; metinleri Kotlin'de de tutabilirsin)

## Ekranlar (Compose for Wear OS Material 3, `androidx.wear.compose.material3`)

Gezinme: `SwipeDismissableNavHost` (`androidx.wear.compose.navigation`); kaydırarak geri.

1. **Boş durum** (`workout == null`): "Telefonda bir antrenman aç". `phoneReachable == false` ise altına "Telefon bağlı değil".
2. **Hareket listesi:** başlık (antrenman adı), her hareket bir düğme: ad + ilerleme. Hedef varsa "2/3 set", yoksa "2 set".
   Hedefe ulaşılan hareket ✓ ile. Telefon erişilemiyorsa ve bekleyen olay varsa üstte küçük "Bekliyor" notu.
3. **Hareket ekranı:** ad; hedef ("Hedef 3 × 10 · 40 kg", ağırlık yoksa "Hedef 3 × 10"); geçen sefer
   ("Geçen: 37,5 × 10"); **ağırlık** ve **tekrar** alanları (her birinde −/+ ; ağırlık adımı 2,5 kg, en az 0; tekrar adımı 1,
   en az 1). Odaktaki alan **döner çerçeve/taç** ile değişir (`Modifier.onRotaryScrollEvent` + `FocusRequester`;
   ~1 adım / 40 px birikimi). Alana dokunmak odağı ona taşır; odaktaki alan vurgulu çizilir. Başlangıç değerleri hareketin
   `draft`'ı; kullanıcı değiştirirse set eklenene kadar korunur, set eklenince yeni `draft` gelir.
   Altta büyük birincil düğme (`EdgeButton`) **"Set tamam"** → `addSet` → dinlenme sayacına geç.
   Altında bu hareketin setleri ("1. 40 × 10"); bekleyen set saat simgesi ya da soluk renk ile; onaylı sete uzun basınca
   onay iletişimi ("Seti sil?") → `deleteSet`.
4. **Dinlenme sayacı:** dairesel ilerleme (`CircularProgressIndicator`), ortada kalan süre "1:05"; "−15 sn" / "+15 sn"
   (o anki sayacı değiştirir) ve "Atla". Bitince titreşim (`VibratorManager` → `defaultVibrator`, kısa-kısa-uzun desen)
   ve hareket ekranına dönüş. Sayaç çalışırken ekran açık kalsın (`FLAG_KEEP_SCREEN_ON`, bitince kaldır).
   Sayacın başlangıç süresi `RestSettingsStore`'dan; hareket listesinin altındaki "Dinlenme: 1:30" düğmesi süreyi
   15 sn adımlarla 15 sn – 10 dk arasında ayarlatır (aynı −/+ ve taç deseni).

## Yapı

- `WatchWorkoutViewModel(repository, restSettings, clock: () -> Long = SystemClock::elapsedRealtime)`: `StateFlow` ile
  ekran durumu; sayaç `viewModelScope` içinde ~200 ms'de bir güncellenir, bitiş zamanı saklanır (kayma olmasın).
  Fabrika: `viewModelFactory { initializer { … } }`, `MainActivity` `WatchApp`'ten repository'yi verir.
- Saf yardımcılar (`domain/`, JVM testli): `formatWeight(37.5) == "37,5"`, `formatWeight(40.0) == "40"`,
  `formatSet(w, r) == "40 × 10"`, `formatDuration(65) == "1:05"`, kalan süre/ilerleme hesabı, ağırlık/tekrar/süre sınırlama.
- `RestSettingsStore`: DataStore (`name = "rest_settings"`), varsayılan 90 sn.
- **Tema:** `MaterialTheme(colorScheme = …)` koyu zemin, birincil renk turuncu (#FF8A3D civarı); tek yerde (`ui/theme/`).
  Renkler ekranlarda sabit yazılmaz, temadan okunur. Yazılar Türkçe, sayılar büyük ve kalın.
- Ekran önizlemeleri (`@Preview(device = WearDevices.SMALL_ROUND)` vb.) sahte bir `WorkoutSyncRepository` ile.
- Dokunulabilir her şey en az 48 dp; yuvarlak ekranda kenarlara taşma olmasın (`ScreenScaffold` + kaydırılabilir liste).

## Doğrulama

`wear/` içinde: `.\gradlew.bat testDebugUnitTest --offline --console=plain` ve `.\gradlew.bat assembleDebug --offline --console=plain`.
AC'nin dosyaları yarım olabilir: derleme hatası yalnızca `data/PhoneSyncRepository.kt`, `PendingEventStore.kt`,
`DisplayWorkout.kt` ya da `WatchApp.kt`'deyse raporda belirt, düzeltmeye çalışma.
