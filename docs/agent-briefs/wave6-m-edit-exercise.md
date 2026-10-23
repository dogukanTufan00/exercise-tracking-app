# Dalga 6 – Ajan M: Hareket düzenleme (#10)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil). Bu görev mevcut kodu **değiştirir**; önce ilgili
dosyaları baştan sona oku. **İstisna:** bu görevde `WorkoutRepository` arayüzüne bir metot ekleyeceksin; ortak
kurallardaki "sözleşmeyi değiştirme" maddesi yalnızca bu metot için kalkar.

## Bağlam

Yanlış işaretlenmiş bir hareket (ör. "Biceps curl" → Bacak) şu an düzeltilemiyor. Setler harekete `exercise_id` ile
bağlı olduğu için katalogdaki satırı güncellemek tüm geçmişi düzeltir. **Şema değişmez.**

## Dokunabileceğin dosyalar

- `lib/data/repositories/workout_repository.dart` (yalnızca yeni metot)
- `lib/data/repositories/sqlite_workout_repository.dart`
- `test/fakes/fake_workout_repository.dart`
- `test/data/repositories/workout_repository_contract.dart`
- `lib/ui/core/widgets/exercise_edit_dialog.dart` (yeni)
- `test/ui/core/widgets/exercise_edit_dialog_test.dart` (yeni)
- `lib/ui/exercise_detail/exercise_detail_view_model.dart`
- `lib/ui/exercise_detail/exercise_detail_screen.dart`
- `test/ui/exercise_detail/exercise_detail_view_model_test.dart`
- `test/ui/exercise_detail/exercise_detail_screen_test.dart`
- `lib/ui/exercises/exercises_screen.dart`
- `test/ui/exercises/exercises_screen_test.dart`
- `lib/ui/workout/workout_view_model.dart`
- `lib/ui/workout/workout_screen.dart`
- `lib/ui/workout/widgets/exercise_card.dart`
- `test/ui/workout/workout_view_model_test.dart`
- `test/ui/workout/workout_screen_test.dart`

## 1. Repository

`WorkoutRepository`'nin "Hareket kataloğu" bölümüne, `createExercise`'ın altına:

```dart
/// Katalogdaki hareketin adını ve kas grubunu değiştirir; güncellenmiş hareketi döndürür.
///
/// Ad kırpılarak saklanır; boşsa [ArgumentError]. Normalleştirilmiş adı (`normalizeForSearch`)
/// **başka** bir hareketinkiyle aynıysa [DuplicateExerciseException] (hareketin kendi adının
/// büyük/küçük harfini değiştirmek serbesttir: "bench press" → "Bench Press"). Hareket yoksa [ArgumentError].
/// Değişiklik hareketin tüm geçmişine yansır.
Future<Exercise> updateExercise(int id, {required String name, required MuscleGroup muscleGroup});
```

- SQLite: `createExercise` ile aynı desen (`_cleanText`, `normalizeForSearch`, transaction içinde çakışma kontrolü,
  kontrol **kendi id'sini hariç tutar**). `exercises.name` sütunu `UNIQUE COLLATE NOCASE`; kendi adının harf
  büyüklüğünü değiştirmek bu kısıta takılmaz.
- Fake: aynı kurallar.
- Sözleşme testleri (`workout_repository_contract.dart`, "hareket kataloğu" grubu): ad ve grup değişir ve
  `searchExercises` yeni adla bulur; ad kırpılır; boş ad → `ArgumentError`; başka hareketin adı (farklı harf
  büyüklüğü / Türkçe karakterle, ör. "SINAV" ↔ "Şınav") → `DuplicateExerciseException`; kendi adının harf
  büyüklüğü değişebilir; olmayan id → `ArgumentError`; değişiklik geçmiş antrenmanın detayında
  (`getWorkoutDetail`) görünür.

## 2. Düzenleme diyaloğu (`lib/ui/core/widgets/exercise_edit_dialog.dart`)

```dart
/// Düzenlenmiş değerler.
typedef ExerciseEdit = ({String name, MuscleGroup muscleGroup});

/// Hareketin adını ve kas grubunu düzenleme diyaloğunu açar. İptalde `null` döner.
Future<ExerciseEdit?> showExerciseEditDialog(BuildContext context, Exercise exercise);
```

- `AlertDialog`, başlık `Hareketi düzenle`.
- İçerik: ad `TextField` (mevcut adla dolu, etiket `Ad`), altında `Kas grubu` yardımcı metni ve
  `MuscleGroup.values` için `MuscleGroupChip(selected:, onTap:)` içeren bir `Wrap`. Hareket seç ekranındaki
  "yeni hareket" bölümünü örnek al.
- Butonlar: `İptal` (`TextButton`) ve `Kaydet` (`FilledButton`). Kırpılmış ad boşsa `Kaydet` devre dışı.
  Hiçbir şey değişmediyse de `Kaydet` serbest (basınca `null` değil, aynı değerler döner; çağıran bunu yok sayabilir).
- Dar ekranda içerik kaydırılabilir olsun (`SingleChildScrollView`).
- Test: mevcut değerlerle açılır; ad değiştirip grup seçip `Kaydet` → değerler döner; `İptal` → `null`;
  ad boşken `Kaydet` devre dışı; 360 × 780, yazı 1.3'te taşma yok.

## 3. Hareket detay ekranı

- `ExerciseDetailViewModel`: `exercise` artık değişebilir (`Exercise get exercise`, private alan).
  Yeni metot:
  ```dart
  /// Hareketi günceller. Başarılıysa `true`. Hata mesajları:
  /// aynı ad → 'Bu adda bir hareket zaten var.'; diğer → 'Hareket güncellenemedi.'
  Future<bool> updateExercise(String name, MuscleGroup muscleGroup);
  ```
  Başarılıysa `exercise` yeni değeri alır ve dinleyiciler uyarılır. Değer değişmediyse repository'yi çağırmadan
  `true` döner.
- Ekran: `AppBar` `actions`'a `IconButton(Icons.edit_outlined, tooltip: 'Hareketi düzenle')` → diyalog →
  `updateExercise`. Başlık ve kas grubu etiketi yeni değerleri gösterir. Hata SnackBar ile (mevcut desen).

## 4. Hareketler listesi

Detay ekranından dönünce (`await Navigator.push`) listeyi mevcut sorguyla yenile (`search(viewModel.query)`):
ad ya da grup değişmiş olabilir.

## 5. Antrenman ekranı

- `ExerciseCard`: yeni parametre `required VoidCallback onEditExercise`; ⋮ menüsüne `İlerleme` ile
  `Hareketi kaldır` arasına `Hareketi düzenle` (değer `'edit'`).
- `WorkoutViewModel`:
  ```dart
  /// Katalogdaki hareketi günceller ve antrenmanı yeniden yükler. Başarılıysa `true`.
  /// Hata mesajları detay ekranındakilerle aynı.
  Future<bool> updateExercise(int exerciseId, String name, MuscleGroup muscleGroup);
  ```
- `workout_screen.dart`: `onEditExercise` → `showExerciseEditDialog(context, entry.exercise)` → sonuç varsa
  `vm.updateExercise(...)`. Ayrıca `İlerleme` ile açılan detay ekranından dönünce `vm.load()` çağır (orada
  düzenleme yapılmış olabilir). `load()`'un açık/kapalı kart durumunu bozmadığını kontrol et.

## 6. Testler (yukarıdakilere ek)

- `ExerciseDetailViewModel`: başarılı güncelleme `exercise`'ı değiştirir; çakışmada mesaj ve `false`; değişiklik
  yoksa repository çağrılmaz.
- Detay ekranı: düzenle → yeni ad AppBar'da, yeni kas grubu etiketi görünür.
- Hareketler ekranı: detayda düzenleyip geri dönünce listede yeni ad görünür.
- `WorkoutViewModel`: `updateExercise` sonrası `detail` yeni adı/grubu içerir; çakışmada `errorMessage`.
- Antrenman ekranı: ⋮ → `Hareketi düzenle` → kaydet → kart başlığında yeni ad.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
