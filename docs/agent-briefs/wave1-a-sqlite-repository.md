# Dalga 1 – Ajan A: SQLite repository

Önce [ortak kuralları](README.md) oku.

## Amaç

`WorkoutRepository` arayüzünün gerçek, SQLite (`sqflite`) tabanlı uygulamasını yazmak.

## Dokunabileceğin dosyalar (yalnızca bunlar, hepsi yeni)

- `lib/data/services/database_service.dart`
- `lib/data/repositories/sqlite_workout_repository.dart`
- `test/data/repositories/sqlite_workout_repository_test.dart`

## 1. `DatabaseService`

```dart
class DatabaseService {
  DatabaseService({DatabaseFactory? factory, String? path});
  static const int schemaVersion = 1;
  Future<Database> get database; // ilk çağrıda açar, sonra aynı örneği döner
  Future<void> close();
}
```

- `factory` verilmezse `sqflite` paketinin `databaseFactory`'si; `path` verilmezse
  `join(await getDatabasesPath(), 'exercise_tracking.db')` (`package:path`).
- `openDatabase` yerine `factory.openDatabase(path, options: OpenDatabaseOptions(...))` kullan, böylece testte
  `databaseFactoryFfi` verilebilir.
- `onConfigure`: `PRAGMA foreign_keys = ON` (yoksa `ON DELETE CASCADE` çalışmaz).
- `onCreate`: `docs/ARCHITECTURE.md` §4'teki şemayı **birebir** oluştur (tablolar, CHECK'ler, index'ler).
  Her ifadeyi ayrı `execute` ile çalıştır, tamamını tek bir `batch` ya da transaction içinde yap.
- Eşzamanlı iki `database` çağrısı veritabanını iki kez açmamalı (açılış `Future`'ını sakla).

## 2. `SqliteWorkoutRepository implements WorkoutRepository`

- Kurucu: `SqliteWorkoutRepository(DatabaseService databaseService)`.
- Her metodun davranışı `workout_repository.dart` içindeki yorumlarda tanımlı; **o yorumlara harfiyen uy**.
- SQL'de her zaman parametre kullan (`?` + `whereArgs`/`arguments`), asla string birleştirme.
- Birden fazla adım içeren işlemleri (`removeExerciseFromWorkout` + yeniden sıralama, `deleteSet` + yeniden
  numaralama, `addExerciseToWorkout` / `addSet` içinde sıradaki numarayı bulup ekleme) `db.transaction` içinde yap.
- Metin kırpma: `trim()`; kırpılmış metin boşsa `null`.
- `createExercise`: önce `SELECT ... WHERE name = ? COLLATE NOCASE` ile kontrol et, varsa
  `DuplicateExerciseException(trimmedName)`. Boş ad → `ArgumentError`.
- `searchExercises`: `WHERE name LIKE ? COLLATE NOCASE` (değer `'%$query%'`), `ORDER BY name COLLATE NOCASE`.
  Sorgu kırpılmış hali boşsa `WHERE` olmadan tümü.
- Set doğrulaması (`addSet`, `updateSet`): `weightKg < 0` veya `reps <= 0` → veritabanına gitmeden `ArgumentError`.
- `getWorkoutSummaries`: N+1 sorgudan kaçın; antrenmanları, hareket sayılarını, set sayılarını ve kas gruplarını
  birkaç sorguyla (JOIN/GROUP BY) çek, Dart'ta birleştir. Kas grupları: hareketlerin `position` sırasına göre,
  her grup bir kez.
- `getWorkoutDetail`: hareketler `position`, setler `set_number` sırasıyla.
- `getPreviousSets`: `beforeWorkoutId` antrenmanının `started_at` değerini bul; bu hareketi içeren ve
  `started_at` değeri bundan **küçük** olan en son antrenmanı seç (`ORDER BY started_at DESC LIMIT 1`).
  O antrenmanda hareket birden çok kez varsa en küçük `position`'lısını kullan. Antrenman yoksa boş liste.
- `started_at` her zaman `DateTime.toIso8601String()` ile yazılır; ISO metinleri doğru sıralanır.
- Var olmayan id'lerle güncelleme/silme hata fırlatmamalı.

## 3. Test: `sqlite_workout_repository_test.dart`

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'workout_repository_contract.dart';

void main() {
  sqfliteFfiInit();
  late DatabaseService service;
  runWorkoutRepositoryContractTests(
    'SQLite',
    () async {
      service = DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      return SqliteWorkoutRepository(service);
    },
    disposeRepository: (_) => service.close(),
  );
  // + aşağıdaki ek testler
}
```

- Her test **boş** bir veritabanıyla başlamalı. Bellek içi veritabanı kapatılınca silinir; yine de bir test ekle:
  iki ayrı `DatabaseService` örneğinin birbirinin verisini görmediğini doğrula. Görüyorlarsa
  `OpenDatabaseOptions(singleInstance: false)` kullan.
- Ek test: yabancı anahtarlar açık mı? `deleteWorkout` sonrası `exercise_sets` ve `workout_exercises`
  tablolarında o antrenmana ait satır kalmamalı (ham SQL ile `SELECT COUNT(*)`).
- `test/data/repositories/workout_repository_contract.dart` dosyasını **değiştirme**; tüm sözleşme testleri geçmeli.

## Bitti sayılması için

- `flutter analyze lib/data test/data` temiz
- `flutter test test/data/repositories/sqlite_workout_repository_test.dart` tamamen geçiyor
