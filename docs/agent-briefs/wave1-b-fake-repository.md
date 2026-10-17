# Dalga 1 – Ajan B: Sahte (bellek içi) repository

Önce [ortak kuralları](README.md) oku.

## Amaç

ViewModel testlerinde gerçek veritabanı yerine kullanılacak, tamamen bellekte çalışan bir `WorkoutRepository`
yazmak. Gerçek SQLite uygulamasıyla **birebir aynı davranmalı**; bunu ortak sözleşme testleri doğrular.

## Dokunabileceğin dosyalar (yalnızca bunlar, hepsi yeni)

- `test/fakes/fake_workout_repository.dart`
- `test/fakes/fake_workout_repository_test.dart`

(Dosya `test/` altında çünkü sadece testler kullanır; uygulama paketine girmez.)

## 1. `FakeWorkoutRepository implements WorkoutRepository`

- Saf Dart; Flutter, `sqflite` veya dosya sistemi kullanma.
- Her "tablo" için bir `Map<int, Model>` (`_workouts`, `_exercises`, `_workoutExercises`, `_sets`) ve her biri için
  1'den başlayan ayrı bir id sayacı tut. Silinen id'ler tekrar kullanılmaz (SQLite AUTOINCREMENT gibi).
- Modeller değişmez (`final` alanlar); güncellemelerde `copyWith` ile yeni nesne oluşturup map'e yaz.
- Her metodun davranışı `lib/data/repositories/workout_repository.dart` içindeki yorumlarda tanımlı;
  **o yorumlara harfiyen uy**. Özellikle:
  - Metinler `trim()` edilir; boşsa `null`.
  - Harf büyüklüğü duyarsız karşılaştırma ve sıralama: `toLowerCase()` ile.
  - `createExercise`: aynı ad (duyarsız) → `DuplicateExerciseException(trimmedName)`; boş ad → `ArgumentError`.
  - `addSet` / `updateSet`: `weightKg < 0` veya `reps <= 0` → `ArgumentError`.
  - `deleteWorkout`: o antrenmanın hareketlerini ve setlerini de sil (SQLite'taki `ON DELETE CASCADE` gibi).
  - `removeExerciseFromWorkout`: setlerini de sil, kalan hareketlerin `position`'larını 0'dan yeniden ver.
  - `deleteSet`: kalan setleri 1'den yeniden numarala.
  - Sıralamalar: özetler `startedAt` azalan; hareketler `position`; setler `setNumber`; katalog ad (A→Z, duyarsız).
  - `getWorkoutSummaries` kas grupları: hareketlerin `position` sırasına göre, her grup bir kez.
  - `getPreviousSets`: `beforeWorkoutId`'nin `startedAt`'inden **kesinlikle önce** başlamış ve bu hareketi
    içeren en son antrenman; orada hareket birden çok kez varsa en küçük `position`'lısının setleri.
  - Var olmayan id'lerle güncelleme/silme sessizce hiçbir şey yapmaz.
- Döndürdüğün listeler çağıranın değiştirebileceği iç listeler olmamalı (yeni liste döndür veya `List.unmodifiable`).

## 2. Test: `fake_workout_repository_test.dart`

```dart
import '../data/repositories/workout_repository_contract.dart';
import 'fake_workout_repository.dart';

void main() {
  runWorkoutRepositoryContractTests('Fake', () async => FakeWorkoutRepository());
}
```

`test/data/repositories/workout_repository_contract.dart` dosyasını **değiştirme**; tüm sözleşme testleri geçmeli.

## Bitti sayılması için

- `flutter analyze test/fakes` temiz
- `flutter test test/fakes/fake_workout_repository_test.dart` tamamen geçiyor
