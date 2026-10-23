# Dalga 11 – Ajan W2: Program günü düzenleme (#16)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil), `docs/ARCHITECTURE.md` §14 ve `docs/DESIGN.md`.
Bu dalgada üç ajan daha çalışıyor: W1 program sekmesi (`lib/ui/app_shell.dart`, `lib/ui/program/program*`),
X antrenmanı programdan başlatma (`lib/ui/history/`, `lib/ui/workout/`), Y yedekleme. Listende olmayan dosyaya dokunma.

## Hazır olanlar (DEĞİŞTİRME, kullan)

- `ProgramRepository` ve modeller (bkz. W1 brief'i ve doc yorumları). `getProgramDetail` ile günü bulabilirsin; gün id'sinden
  programa ulaşmak için ViewModel'de ilk yüklemede programları gezip günü bul ya da `getActiveProgramDetail` + diğerleri.
- `ExercisePickerScreen()` (`lib/ui/exercise_picker/`): `Navigator.push<Exercise>` ile açılır, seçilen hareketle döner.
- `NumberStepper` (`lib/ui/core/widgets/number_stepper.dart`), `formatWeekday`, `formatWeekdayShort`, `formatTarget`.
- Testler için `FakeProgramRepository(FakeWorkoutRepository())`.

## Dokunabileceğin dosyalar

- `lib/ui/program/day_edit_screen.dart` (iskelet var; doldur, kurucu `DayEditScreen({super.key, required this.dayId})` kalır)
- `lib/ui/program/day_edit_view_model.dart` (yeni)
- `lib/ui/program/widgets/target_dialog.dart` (yeni)
- `test/ui/program/day_edit_screen_test.dart`, `day_edit_view_model_test.dart`, `target_dialog_test.dart` (yeni)

## 1. Ekran

- AppBar başlığı gün adı; `actions`: `IconButton(Icons.edit_outlined, tooltip: 'Günü yeniden adlandır')` → ad diyaloğu;
  ⋮ menüsü `Günü sil` (onay: "Gün ve hareketleri programdan silinecek.") → `deleteDay` → ekran kapanır.
- Üstte **planlanan gün** seçimi: `Esnek` + 7 kısa gün (`formatWeekdayShort`) içeren tek seçimli bir `Wrap` (ChoiceChip ya
  da `MuscleGroupChip` benzeri); seçim hemen `updateDay` ile kaydedilir. Aynı programda iki gün aynı güne konabilir (yasak yok).
- Hareket listesi (sırayla): ad (`titleMedium`), hedef (`formatTarget`, soluk). Satıra dokununca hedef diyaloğu →
  `updateDayExerciseTarget`. Satırda ⋮: `Yukarı taşı` / `Aşağı taşı` (`reorderDayExercises`), `Çıkar` (`removeDayExercise`).
- `FloatingActionButton` (tooltip `Hareket ekle`) → `ExercisePickerScreen` → seçilirse hedef diyaloğu (varsayılan 3 × 10,
  ağırlık yok) → `addDayExercise`.
- Boş durum: `EmptyState(icon: Icons.fitness_center, title: 'Henüz hareket yok', message: 'Bu güne yapacağın hareketleri ekle.')`.
- Hatalar SnackBar ile (README deseni).

## 2. Hedef diyaloğu (`widgets/target_dialog.dart`)

```dart
/// Hareket hedefi: set sayısı, tekrar ve isteğe bağlı ağırlık. İptalde null.
Future<ExerciseTarget?> showTargetDialog(BuildContext context, {required String exerciseName, ExerciseTarget? initial});
```

- Başlık hareket adı. `Set` (NumberStepper, adım 1, en az 1), `Tekrar` (adım 1, en az 1), `Ağırlık hedefi` anahtarı
  (`SwitchListTile`); açıksa `Ağırlık` (NumberStepper, adım 2,5, kg). Kapalıysa `weightKg` null.
- Dar ekranda (360 dp, yazı 1.3) adımlayıcılar taşmamalı: gerekirse alt alta (bkz. `WeightRepsSteppers`'taki yaklaşım),
  içerik `SingleChildScrollView` içinde.
- `İptal` / `Kaydet`.

## 3. Testler

ViewModel: yükleme, gün adı/planlanan gün değişimi, hareket ekleme/hedef güncelleme/çıkarma/sıralama, gün silme.
Ekran: seçim çipi ile gün kaydedilir; picker'dan hareket eklenir (picker'ı gerçekten aç, bir harekete dokun); hedef
diyaloğu ağırlık anahtarıyla; 360 × 780, yazı 1.3'te ekran ve diyalog taşmaz.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
