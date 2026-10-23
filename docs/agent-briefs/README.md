# Ajan talimatları

Bu klasör, kodun bir kısmını yazan yapay zekâ ajanlarına (Claude Haiku) verilen görev tanımlarını içerir.
Mimar/orkestratör (Claude Opus) işi parçalara böler, her ajana bir talimat verir, çıkan kodu inceler ve birleştirir.

## Ortak kurallar (her ajan için geçerli)

1. **Önce oku:** `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `lib/data/models/` altındaki tüm dosyalar,
   `lib/data/repositories/workout_repository.dart`, `lib/data/repositories/settings_repository.dart`,
   `lib/ui/core/theme/app_spacing.dart`.
2. **Sadece görevinde listelenen dosyaları oluştur/değiştir.** Başka ajanlar aynı anda aynı projede çalışıyor;
   listende olmayan bir dosyaya dokunmak onların işini bozar. Modelleri ve arayüzleri (sözleşmeyi) değiştirme.
3. Sözleşmede bir eksik/hata olduğunu düşünürsen **değiştirme**, raporunda açıkça yaz.
4. **Yasak komutlar:** `flutter pub get/add/upgrade`, `flutter create`, `flutter clean`, her türlü `git` komutu.
   Yeni paket gerekiyorsa kullanma, raporda belirt.
5. **Doğrulama** (PowerShell, proje kökünde):
   - `& 'C:\dev\flutter\bin\flutter.bat' analyze <kendi dosyaların>` → "No issues found!" olmalı
   - `& 'C:\dev\flutter\bin\flutter.bat' test <kendi test dosyaların>` → tüm testler geçmeli
   - Diğer ajanlar da Flutter çalıştırdığı için "Waiting for another flutter command to release the startup lock"
     görebilirsin; bu normal, bekle.
6. **Kod stili:** `flutter_lints` kuralları, `const` kullanılabilen her yerde `const`, kullanıcıya görünen metinler
   Türkçe, sınıf/değişken adları İngilizce, açıklayıcı ama kısa doküman yorumları (`///`), mevcut dosyaların
   biçimine benzer kod.
7. **Bitirdiğinde rapor ver:** oluşturduğun/değiştirdiğin dosyalar, `analyze` ve `test` çıktılarının son satırları
   (aynen), varsa emin olmadığın kararlar ve sözleşmeyle ilgili notlar.

## Dalga 2 ortak kuralları (ekranlar)

**Uygulamada hazır olanlar** (değiştirme, kullan):
- Veri: `WorkoutRepository` arayüzü, modeller (`lib/data/models/models.dart`), `normalizeForSearch`.
- Tema: `buildAppTheme(AppThemeId)`, `AppPalette.of(id)`, `AppSpacing`.
- Bileşenler: `NumberStepper`, `MuscleGroupChip`, `EmptyState` (`lib/ui/core/widgets/`).
- Biçimlendiriciler: `formatWeight`, `formatSet`, `formatWorkoutDate`, `parseDecimal` (`lib/ui/core/formatters.dart`).
- Testler için: `FakeWorkoutRepository` (`test/fakes/fake_workout_repository.dart`).
Bunların dosyalarını açıp imzalarını oku; tahmin etme.

**Sağlayıcılar (provider):** `main.dart` ağacın en üstüne şunları koyar:
`Provider<WorkoutRepository>`, `Provider<SettingsRepository>`, `ChangeNotifierProvider<ThemeController>`.
Ekranlar repository'yi `context.read<WorkoutRepository>()` ile alır.

**Ekran deseni (MVVM):**
```dart
class XScreen extends StatelessWidget {
  const XScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => XViewModel(context.read<WorkoutRepository>())..load(),
      child: const _XView(),
    );
  }
}
```
- ViewModel `ChangeNotifier`'dır; durumu private alanlarda tutar, getter'larla açar; `isLoading` ve
  `String? errorMessage` alanları vardır. Repository hatalarını yakalar, `errorMessage`'a Türkçe mesaj yazar;
  ekran bunu `SnackBar` ile gösterir ve `clearError()` çağırır.
- `await` sonrası `notifyListeners()` çağırmadan önce ViewModel'in dispose edilmediğini kontrol et
  (`bool _disposed`, `dispose()` içinde `true`).
- ViewModel Flutter widget'larını import etmez (`package:flutter/foundation.dart` yeterli).

**Ekranlar arası sözleşme (iskeletler hazır; kurucu imzalarını DEĞİŞTİRME):**
| Ekran | Dosya | Kurucu | Nasıl açılır / ne döner |
|---|---|---|---|
| Geçmiş | `lib/ui/history/history_screen.dart` | `HistoryScreen()` | Açılış ekranı |
| Antrenman | `lib/ui/workout/workout_screen.dart` | `WorkoutScreen(workoutId: int)` | `Navigator.push`; kapanınca çağıran listeyi yeniler |
| Hareket seç | `lib/ui/exercise_picker/exercise_picker_screen.dart` | `ExercisePickerScreen()` | `Navigator.push<Exercise>`; seçilen hareketle `pop` eder, geri dönülürse `null` |
| Ayarlar | `lib/ui/settings/settings_screen.dart` | `SettingsScreen()` | Geçmiş ekranındaki ayarlar ikonundan |

**Arayüz kuralları:** `docs/DESIGN.md`'ye uy. Renk/yazı yalnızca `Theme.of(context)` üzerinden;
boşluklar `AppSpacing` ile; dokunulabilir her şey en az 48 px; ekranda **en fazla bir** `FilledButton`;
kullanıcıya görünen tüm metinler Türkçe.

**Testler:** ViewModel testleri `FakeWorkoutRepository` ile; widget testleri şöyle sarılır:
```dart
setUpAll(() => initializeDateFormatting('tr'));
await tester.pumpWidget(
  Provider<WorkoutRepository>.value(
    value: repository,
    child: MaterialApp(theme: buildAppTheme(AppThemeId.darkOrange), home: const XScreen()),
  ),
);
await tester.pumpAndSettle();
```

## Dalgalar

| Dalga | Ajan | Görev |
|---|---|---|
| 1 | A | [SQLite repository](wave1-a-sqlite-repository.md) |
| 1 | B | [Sahte (bellek içi) repository](wave1-b-fake-repository.md) |
| 1 | C | [Tema sistemi + ayarlar repository](wave1-c-theme-settings.md) |
| 1 | D | [Ortak bileşenler + biçimlendiriciler](wave1-d-common-widgets.md) |
| 2 | E | [Geçmiş ekranı](wave2-e-history.md) |
| 2 | F | [Antrenman ekranı](wave2-f-workout.md) |
| 2 | G | [Hareket seç ekranı](wave2-g-exercise-picker.md) |
| 2 | H | [Ayarlar ekranı + uygulama girişi (main.dart)](wave2-h-settings-app.md) |
| 3 | I | [Katlanabilir hareket kartları + stepper taşma düzeltmesi](wave3-i-collapsible-cards.md) |
| 4 | J1 | [Repository'lerde yedekleme (#1)](wave4-j1-backup-repositories.md) |
| 4 | J2 | [JSON ve CSV biçimleri (#1)](wave4-j2-backup-codecs.md) |
| 4 | K | [Ayarlar > Veriler bölümü (#1)](wave4-k-backup-settings-ui.md) |
| 5 | L | [İlerleme ekranına giriş noktaları (#7)](wave5-l-progress-entry-points.md) |
| 6 | M | [Hareket düzenleme (#10)](wave6-m-edit-exercise.md) |
| 7 | N | [Antrenmanda rekor vurgusu (#8)](wave7-n-record-highlight.md) |
| 8 | O | [Ölçümlerin veri katmanı ve ilk şema geçişi (#14)](wave8-o-measurement-data.md) |
| 8 | P | [Geçmişi haftalara göre gruplama (#15)](wave8-p-week-grouping.md) |
| 9 | Q | [Alt gezinme çubuğu (#13)](wave9-q-bottom-navigation.md) |
| 9 | R | [Profil ve ölçüm ekranları (#14)](wave9-r-profile-screen.md) |
| 9 | S | [Yedekte ölçümler, biçim 2 (#14)](wave9-s-backup-v2.md) |
