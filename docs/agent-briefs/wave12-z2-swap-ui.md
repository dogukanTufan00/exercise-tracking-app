# Dalga 12b – Ajan Z2: Antrenmanda hareketi değiştirme (#11)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil). Bu dalgada Ajan Z3 aynı anda `lib/ui/exercise_detail/`
ve `lib/ui/exercises/` üzerinde çalışıyor; listende olmayan dosyaya dokunma.

## Amaç

Antrenmanda yanlış hareket seçilip setler girildiyse (ör. Leg extension yerine Leg curl), setleri silmeden kaydın
hareketi değiştirilebilsin. Yalnızca bu antrenman değişir; katalog değişmez (katalogdaki adı düzeltmek "Hareketi düzenle").

## Hazır olanlar

- `WorkoutRepository.changeWorkoutExercise(workoutExerciseId, exerciseId)` (uygulaması ve testleri hazır).
- `ExercisePickerScreen()` (`Navigator.push<Exercise>`; seçilen hareketle döner, vazgeçilirse `null`).

## Dokunabileceğin dosyalar

- `lib/ui/workout/workout_view_model.dart`, `lib/ui/workout/workout_screen.dart`, `lib/ui/workout/widgets/exercise_card.dart`
- `test/ui/workout/workout_view_model_test.dart`, `test/ui/workout/workout_screen_test.dart`

## Yapılacaklar

- `ExerciseCard`: yeni parametre `required VoidCallback onChangeExercise`; ⋮ menüsüne `Hareketi düzenle`'nin
  altına `Hareketi değiştir` (değer `'change'`).
- `workout_screen.dart`: seçilince `ExercisePickerScreen` açılır; bir hareket seçilir ve mevcut hareketten farklıysa
  `vm.changeExercise(workoutExerciseId, exercise.id)`.
- `WorkoutViewModel.changeExercise(int workoutExerciseId, int exerciseId)`: repository'yi çağırır, sonra antrenmanı
  **tam** yeniden yükler (`_reloadAll`: "geçen sefer" setleri ve rekorlar yeni hareket için hesaplanmalı). Kartın açık/kapalı
  durumu ve taslağı korunur. Hata: `'Hareket değiştirilemedi.'`. Başarıda SnackBar: `'Hareket değiştirildi'`
  (ekranın mevcut mesaj desenine uygun; gerekirse ViewModel'e bir bilgi mesajı alanı ekle).

## Testler

ViewModel: değiştirme sonrası kayıt yeni hareketi gösterir, setler aynı, "geçen sefer" yeni hareketinki; aynı hareket
seçilirse hiçbir şey olmaz; hata mesajı. Ekran: ⋮ → `Hareketi değiştir` → picker'da bir harekete dokun → kart başlığında
yeni ad, setler duruyor.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
