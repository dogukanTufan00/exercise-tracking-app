# Dalga 12a – Ajan Z1: Hareket değiştirme ve birleştirme, veri katmanı (#11, #12)

Önce [ortak kuralları](README.md) oku ve `docs/ARCHITECTURE.md` §4 ile §14. Bu dalgada çalışan tek ajansın.

## Hazır olan sözleşme (DEĞİŞTİRME, uygula)

`lib/data/repositories/workout_repository.dart` içinde iki yeni metot (kuralları doc yorumunda):

- `changeWorkoutExercise(int workoutExerciseId, int exerciseId)` (#11)
- `mergeExercises({required int sourceId, required int targetId})` (#12)

## Dokunabileceğin dosyalar

- `lib/data/repositories/sqlite_workout_repository.dart`
- `test/fakes/fake_workout_repository.dart`
- `test/fakes/fake_program_repository.dart` (yalnızca birleştirmede program günlerinin güncellenmesi için)
- `test/data/repositories/workout_repository_contract.dart`
- `test/data/repositories/sqlite_workout_repository_test.dart`
- `test/fakes/fake_program_repository_test.dart`

## 1. SQLite

- `changeWorkoutExercise`: kayıt ve hareket var mı kontrol et (`_requireExists` deseni), sonra
  `UPDATE workout_exercises SET exercise_id = ? WHERE id = ?`. Tek transaction.
- `mergeExercises`: tek transaction; iki id aynıysa ya da biri yoksa `ArgumentError`;
  `UPDATE workout_exercises SET exercise_id = target WHERE exercise_id = source`;
  `UPDATE program_day_exercises SET exercise_id = target WHERE exercise_id = source`;
  `DELETE FROM exercises WHERE id = source`. (`program_day_exercises.exercise_id` `ON DELETE RESTRICT`; önce taşı, sonra sil.)

## 2. Sahte repository'ler

- `FakeWorkoutRepository`: aynı kurallar. Birleştirmede program günlerini de güncellemek için
  `FakeWorkoutRepository`'ye bir dinleyici ekle (ör. `void Function(int sourceId, int targetId)? onExercisesMerged`
  ya da bir liste); `FakeProgramRepository` kurucusunda kendini kaydeder ve kendi gün hareketlerindeki `exerciseId`'leri
  günceller. Mevcut davranışı değiştirme.

## 3. Testler

- Sözleşme (`workout_repository_contract.dart`):
  - `changeWorkoutExercise`: setler/not/sıra korunur, `getWorkoutDetail` yeni hareketi gösterir; "geçen sefer" ve
    `getExerciseHistory` yeni hareket altında görünür, eski hareketin geçmişinden çıkar; olmayan kayıt/hareket → `ArgumentError`.
  - `mergeExercises`: kaynağın tüm antrenman kayıtları hedefe geçer (setleriyle); kaynak katalogdan silinir
    (`searchExercises` bulmaz); hedefin adı/kas grubu aynı; aynı id ya da olmayan id → `ArgumentError` ve hiçbir şey değişmez.
- SQLite'a özgü (`sqlite_workout_repository_test.dart`): kaynak bir program gününde kullanılıyorsa birleştirme sonrası
  gün hareketi hedefi gösterir (`SqliteProgramRepository` ile, aynı `DatabaseService`).
- Fake program testi: aynı senaryo `FakeProgramRepository` ile.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
