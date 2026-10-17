# Dalga 2 – Ajan H: Ayarlar ekranı + uygulama girişi

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil).

## Dokunabileceğin dosyalar

- `lib/ui/core/theme/theme_controller.dart` (yeni)
- `lib/ui/settings/settings_screen.dart` (iskeleti değiştir; kurucu aynı kalmalı)
- `lib/main.dart` (tamamen yeniden yaz)
- `test/fakes/fake_settings_repository.dart` (yeni)
- `test/ui/core/theme/theme_controller_test.dart` (yeni)
- `test/ui/settings/settings_screen_test.dart` (yeni)
- `test/widget_test.dart` (eski sayaç testini sil, uygulama duman testiyle değiştir)

## 1. `ThemeController extends ChangeNotifier`

```dart
ThemeController(SettingsRepository repository)
AppThemeId get themeId;              // load'dan önce AppThemeId.defaultTheme
ThemeData get theme;                 // buildAppTheme(themeId); her themeId için bir kez oluşturup sakla
Future<void> load();
Future<void> setTheme(AppThemeId id); // önce durumu güncelle + notifyListeners (anında görünsün), sonra kaydet
```

## 2. `SettingsScreen`

- `context.watch<ThemeController>()` kullanır (ayrı ViewModel gerekmez; ThemeController onun ViewModel'idir).
- `AppBar` başlığı "Ayarlar". Kenar boşluğu `AppSpacing.screenPadding`.
- Bölüm başlığı `bodySmall` "Tema".
- Her `AppThemeId` için bir satır (`InkWell`, en az 56 yükseklik, `Semantics(selected: ...)`):
  - Solda **tema önizlemesi:** 40×40 daire, dolgu `AppPalette.of(id).background`, 1 px kenarlık
    `AppPalette.of(id).outline`; ortasında 16×16 daire, dolgu `AppPalette.of(id).primary`.
    (Bu ekran, renkleri temadan değil `AppPalette`'ten okuyan tek istisnadır: diğer temaları göstermesi gerekiyor.)
  - Ortada `id.label` (`bodyLarge`).
  - Seçiliyse sağda `Icon(Icons.check_circle, color: colorScheme.primary)`.
  - Dokununca `setTheme(id)`.

## 3. `main.dart`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');            // package:intl/date_symbol_data_local.dart
  final workoutRepository = SqliteWorkoutRepository(DatabaseService());
  final settingsRepository = PrefsSettingsRepository();
  final themeController = ThemeController(settingsRepository);
  await themeController.load();
  runApp(ExerciseTrackerApp(
    workoutRepository: workoutRepository,
    settingsRepository: settingsRepository,
    themeController: themeController,
  ));
}
```

`ExerciseTrackerApp` (aynı dosyada, `StatelessWidget`, üç alanı da `required`):
`MultiProvider` → `Provider<WorkoutRepository>.value`, `Provider<SettingsRepository>.value`,
`ChangeNotifierProvider<ThemeController>.value`; içinde `Consumer<ThemeController>` →
`MaterialApp(title: 'Exercise Tracker', debugShowCheckedModeBanner: false, theme: controller.theme,
home: const HistoryScreen())`.

## 4. Testler

- `fake_settings_repository.dart`: bellekte tutan `FakeSettingsRepository implements SettingsRepository`
  (başlangıç teması kurucuda verilebilir).
- `theme_controller_test.dart`: load öncesi varsayılan; load kayıtlı temayı okur; `setTheme` dinleyicileri
  bilgilendirir ve repository'ye kaydeder; `theme.colorScheme.primary` seçili paletin primary'si.
- `settings_screen_test.dart`: 4 tema adı görünür; seçili temada onay ikonu; başka temaya dokununca
  `ThemeController.themeId` değişir.
- `widget_test.dart`: `ExerciseTrackerApp`'i `FakeWorkoutRepository` + `FakeSettingsRepository` ile pompala
  (`initializeDateFormatting('tr')` `setUpAll`'da), `find.byType(HistoryScreen)` bulunsun. (Geçmiş ekranını
  başka ajan yazıyor; testin yalnızca ekranın varlığına bakması yeterli.)

## Bitti sayılması için

- `flutter analyze lib/main.dart lib/ui/core/theme lib/ui/settings test/ui/settings test/ui/core/theme test/fakes test/widget_test.dart` temiz
- `flutter test test/ui/settings test/ui/core/theme test/widget_test.dart` tamamen geçiyor
