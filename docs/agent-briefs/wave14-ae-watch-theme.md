# Dalga 14 – Ajan AE: Saat telefonun temasını izlesin (#24)

Önce [ortak kuralları](README.md) (Kotlin bölümü dahil) oku, sonra `docs/ARCHITECTURE.md` §15 ve **§15.7**.
Bu dalgada çalışan tek ajansın; işin hem telefon (Dart + Kotlin) hem saat (Kotlin) tarafı var.

## Hazır olan sözleşme (DEĞİŞTİRME, kullan)

- `lib/data/watch/watch_protocol.dart`: `watchThemePath`, `watchThemeKey`.
- `lib/data/watch/wear_channel.dart`: `WearChannel.publishTheme(String)` ve gerçek uygulaması (MethodChannel `publishTheme`).
- `lib/data/watch/watch_sync_service.dart`: `publishTheme(AppThemeId)` iskeleti (gövdeyi sen yazarsın).
- `wear/.../data/WatchProtocol.kt`: `THEME_PATH`, `THEME_KEY`.

## Dokunabileceğin dosyalar

Telefon:
- `lib/data/watch/watch_sync_service.dart` (yalnızca `publishTheme` gövdesi)
- `lib/main.dart`
- `test/fakes/fake_wear_channel.dart` (`publishTheme`'i kaydet: ör. `List<String> publishedThemes`)
- `test/data/watch/watch_sync_service_test.dart` (yalnızca yeni testler)
- `android/app/src/main/kotlin/com/dogukantufan00/exercise_tracking_app/MainActivity.kt`

Saat (`wear/app/src/` altında):
- `main/.../ui/theme/WatchTheme.kt`
- `main/.../data/ThemeSource.kt` (yeni)
- `main/.../domain/WatchThemeId.kt` (yeni, saf Kotlin)
- `main/.../MainActivity.kt`, `main/.../WatchApp.kt`
- `main/.../ui/preview/WatchPreviews.kt` (yalnızca `WatchTheme` imzası değişirse derlensin diye)
- `test/java/com/dogukantufan00/exercise_tracking_app/domain/WatchThemeIdTest.kt` (yeni)

## Telefon

1. `publishTheme(id)` → `channel.publishTheme(id.name)`; hata yakalanır (`debugPrint`).
2. `main.dart`: `themeController.load()` sonrası `unawaited(watchSyncService.publishTheme(themeController.themeId))`;
   `themeController.addListener` ile tema **değiştiğinde** (önceki id'den farklıysa) yeniden yayınla.
3. Kotlin `MainActivity`: `"publishTheme"` → `PutDataMapRequest.create("/settings/theme")`,
   `dataMap.putString("themeId", id)`, `setUrgent()`, `putDataItem`; mevcut `publishSnapshot` deseniyle aynı
   (hata yalnızca `Log.w`, `result.success(null)` hemen). Argüman metin değilse `result.error("bad_args", …)`.
4. Test: `publishTheme(AppThemeId.yellowNavy)` → kanal `'yellowNavy'` aldı.

## Saat

1. `domain/WatchThemeId.kt`: `enum class WatchThemeId { DarkOrange, RedBlack, YellowNavy, LightBlue }` ve
   `fun watchThemeIdOf(name: String?): WatchThemeId` (`"darkOrange"` → `DarkOrange` …; null/bilinmeyen → `DarkOrange`).
   JVM testi: dört ad + null + bilinmeyen.
2. `data/ThemeSource.kt`: `class ThemeSource(context, scope)`; `val themeId: StateFlow<WatchThemeId>`.
   Başlangıç değeri SharedPreferences'tan (`watch_theme`, anahtar `themeId`; senkron okunur ki ilk kare doğru olsun).
   Sonra `DataClient.getDataItems(uri)` ile `/settings/theme`'i okur ve `addListener` ile değişiklikleri dinler
   (`PhoneSyncRepository`'deki deseni izle; `DataEventBuffer` geri çağrı içinde işlenip serbest bırakılır).
   Yeni değeri SharedPreferences'a yazar. Silinen DataItem → değişiklik yok.
3. `WatchApp`: `themeSource = ThemeSource(this, scope)` (public `lateinit` ya da `val`, `syncRepository` gibi).
4. `ui/theme/WatchTheme.kt`: `WatchTheme(themeId: WatchThemeId, content)`. Dört `ColorScheme`, değerler ve eşleme
   **tam olarak** ARCHITECTURE §15.7'deki tablodan. Ekran dosyalarına dokunma; onlar zaten `MaterialTheme.colorScheme` okuyor.
   (Kontrol et: ekranlarda sabit `Color(0x…)` varsa raporda listele, değiştirme.)
5. `MainActivity`: `val themeId by (application as WatchApp).themeSource.themeId.collectAsStateWithLifecycle()`
   → `WatchTheme(themeId) { … }`.

## Doğrulama

- Proje kökünde: `& 'C:\dev\flutter\bin\flutter.bat' analyze lib test` → "No issues found!";
  `& 'C:\dev\flutter\bin\flutter.bat' test --timeout 120s` → "All tests passed!".
- `wear/` içinde: `.\gradlew.bat testDebugUnitTest --offline --console=plain` ve `.\gradlew.bat assembleDebug --offline --console=plain`.
- Telefonun Kotlin derlemesini doğrulaman gerekmez (orkestratör `flutter build apk` ile yapar); ama dikkatli yaz.
