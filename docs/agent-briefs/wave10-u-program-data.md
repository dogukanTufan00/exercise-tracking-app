# Dalga 10 – Ajan U: Programların veri katmanı ve şema 3 geçişi (#16)

Önce [ortak kuralları](README.md) oku, sonra `docs/ARCHITECTURE.md` §4 (özellikle **"Şema 3"**) ve §14.
Bu dalgada başka bir ajan aynı anda `lib/ui/app_shell.dart`, `lib/ui/exercises/`, `lib/ui/profile/profile_screen.dart`
ve testleri üzerinde çalışıyor; listende olmayan dosyaya dokunma.

Önceki şema geçişi (v1 → v2) **Dalga 8 Ajan O** tarafından yapıldı; `lib/data/services/database_service.dart`,
`test/data/services/database_service_test.dart`, `lib/data/repositories/sqlite_measurement_repository.dart` ve
`test/fakes/fake_measurement_repository.dart` dosyalarını oku ve **aynı desenleri** kullan.

## Hazır olan sözleşme (DEĞİŞTİRME, uygula)

- `lib/data/models/program.dart`: `ExerciseTarget`, `Program`, `ProgramDay`, `ProgramDayExercise`,
  `ProgramDayExerciseDetail`, `ProgramDayDetail`, `ProgramDetail`.
- `Workout.programDayId` ve `WorkoutExercise.target` (fromMap yeni sütunları okur).
- `lib/data/models/backup_data.dart`: `BackupProgram`, `BackupProgramDay`, `BackupProgramExercise`.
- `lib/data/repositories/program_repository.dart`: `ProgramRepository` arayüzü (her metodun kuralı doc yorumunda).

## Dokunabileceğin dosyalar

- `lib/data/services/database_service.dart`
- `lib/data/repositories/sqlite_program_repository.dart` (yeni)
- `lib/data/repositories/sqlite_workout_repository.dart` (yalnızca okuma sorgularına yeni sütunlar)
- `test/fakes/fake_workout_repository.dart` (yalnızca program desteği için gereken ekler)
- `lib/main.dart`
- `test/widget_test.dart`
- `test/fakes/fake_program_repository.dart` (yeni)
- `test/fakes/fake_program_repository_test.dart` (yeni)
- `test/data/repositories/program_repository_contract.dart` (yeni)
- `test/data/repositories/sqlite_program_repository_test.dart` (yeni)
- `test/data/services/database_service_test.dart`
- `test/data/repositories/workout_repository_contract.dart` (yalnızca yeni sütunların okunduğunu doğrulayan testler)

## 1. Şema geçişi (`DatabaseService`)

- `schemaVersion = 3`; `_schemaV3Statements` (ARCHITECTURE §4 "Şema 3", birebir; `ALTER TABLE` satırları dahil).
- `onCreate`: v1 + v2 + yerleşik türler + v3 (tek transaction).
- `onUpgrade`: mevcut `if (oldVersion < 2)` bloğuna dokunma; altına `if (oldVersion < 3)` bloğu (tek transaction).
  v1'den açılan bir veritabanı iki bloğu da sırayla çalıştırmalı.
- Geçiş testi (`database_service_test.dart`): mevcut testler kalsın; ekle: **v2** veritabanını gerçek dosyada kur
  (v1 + v2 ifadeleri; test için `@visibleForTesting` getter'larla), antrenman + set + ölçüm ekle, kapat →
  `DatabaseService` ile aç → `user_version` 3, eski satırlar aynen, yeni sütunlar `NULL`, program eklenip
  antrenman başlatılabiliyor. Ayrıca v1 → v3 tek seferde.

## 2. `SqliteWorkoutRepository`

Yalnızca okuma: `getWorkoutDetail` ve `getWorkoutSummaries`/diğer `Workout.fromMap` kullanan sorgular yeni
sütunları (`program_day_id`, `target_*`) da seçsin ki modeller dolu gelsin. Yazma davranışı değişmez.
Sözleşme testine: programdan başlatılmış bir antrenmanı simüle etmek SQLite'a özgü olduğundan, burada yalnızca
"normal antrenmanda `programDayId` ve `target` `null`" doğrulaması yeterli.

## 3. `SqliteProgramRepository` (yeni)

- Kurucu: `SqliteProgramRepository(DatabaseService service)`; `SqliteMeasurementRepository`'nin stilini taklit et.
- Arayüzdeki her kural. Notlar:
  - `created_at` = oluşturma anı; `getPrograms` `created_at, id` sırasıyla.
  - `setActiveProgram` ve "ilk program etkin" kuralı tek transaction.
  - `deleteDay` / `removeDayExercise` sonrası sıra yeniden 0…n−1.
  - `reorder*`: liste eksik/fazla/yabancı id içeriyorsa `ArgumentError`.
  - `startWorkoutFromDay`: tek transaction; `workouts` (başlık = gün adı, `program_day_id`) + her hareket için
    `workout_exercises` (position 0…, `target_*` kopyası, `note` NULL). Boş başlık kuralları `SqliteWorkoutRepository`
    ile aynı (gün adı zaten boş olamaz).
  - `exportPrograms` / `importPrograms`: arayüzdeki kurallar; içe aktarma tek transaction, önce doğrula sonra yaz;
    hareket eşleştirme ve oluşturma `SqliteWorkoutRepository.importBackup`'taki gibi `normalizeForSearch` ile.

## 4. `FakeProgramRepository` (yeni)

- Kurucu: `FakeProgramRepository(FakeWorkoutRepository workouts)`. Hareket bilgisi ve antrenman oluşturma için bu
  sahte repository'yi kullanır. Gerekirse `FakeWorkoutRepository`'ye **yalnızca** şu türden ekler yap:
  program günüyle ve hedeflerle antrenman oluşturmaya yarayan, testlerde kullanılan bir yardımcı (ör.
  `createWorkoutFromProgram(...)`), ve hareketi ada göre bul/oluştur yardımcısı. Mevcut davranışı değiştirme.
- Silinen id'ler tekrar kullanılmaz.

## 5. Sözleşme testleri

`program_repository_contract.dart`: `runProgramRepositoryContractTests(name, create, {disposeRepository})`.
`create` hem `ProgramRepository`'yi hem aynı veriyi gören bir `WorkoutRepository`'yi döndürmeli (ör. bir record).
Kapsa: program oluşturma (ilki etkin, ikincisi değil), yeniden adlandırma, etkin yapma (tek etkin), silme
(etkinse etkin kalmaz; o programdan başlatılmış antrenman kalır ve `programDayId` `null` olur); gün ekleme/güncelleme
/silme/sıralama ve geçersiz `weekday`; gün hareketi ekleme/hedef güncelleme/çıkarma/sıralama ve geçersiz hedef;
olmayan hareket/gün → `ArgumentError`; `startWorkoutFromDay` (başlık, `programDayId`, hareket sırası, hedef kopyası,
set yok; program sonra değişince antrenmanın hedefi değişmez); export/import (gidiş-dönüş, aynı adlı program atlanır,
eksik hareket oluşturulur, etkin kuralı, geçersiz değerde hiçbir şey yazılmaz).

## 6. `main.dart`

`SqliteProgramRepository`'yi **aynı** `DatabaseService` örneğiyle oluştur, `Provider<ProgramRepository>` ekle,
`ExerciseTrackerApp`'e `required this.programRepository`. `test/widget_test.dart`'ı güncelle.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
