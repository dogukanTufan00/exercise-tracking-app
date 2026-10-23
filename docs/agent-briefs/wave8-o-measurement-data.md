# Dalga 8 – Ajan O: Ölçümlerin veri katmanı ve ilk şema geçişi (#14)

Önce [ortak kuralları](README.md) oku, sonra `docs/ARCHITECTURE.md` §4 (özellikle **"Şema 2"**) ve §13.
Bu dalgada başka bir ajan aynı anda `lib/ui/history/` ve `lib/domain/` üzerinde çalışıyor; listende olmayan dosyaya
dokunma.

## Hazır olan sözleşme (DEĞİŞTİRME, uygula)

- `lib/data/models/measurement.dart`: `builtinMeasurementTypes`, `MeasurementType`, `BodyMeasurement`,
  `MeasurementSummary`.
- `lib/data/models/backup_data.dart`: `BackupMeasurementType`, `BackupMeasurement`.
- `lib/data/repositories/measurement_repository.dart`: `MeasurementRepository` arayüzü (her metodun kuralı
  doc yorumunda) ve `DuplicateMeasurementTypeException`.
- Ad normalleştirme: `normalizeForSearch` (`lib/data/utils/text_normalizer.dart`).

## Dokunabileceğin dosyalar

- `lib/data/services/database_service.dart`
- `lib/data/repositories/sqlite_measurement_repository.dart` (yeni)
- `lib/main.dart`
- `test/widget_test.dart`
- `test/fakes/fake_measurement_repository.dart` (yeni)
- `test/fakes/fake_measurement_repository_test.dart` (yeni)
- `test/data/repositories/measurement_repository_contract.dart` (yeni)
- `test/data/repositories/sqlite_measurement_repository_test.dart` (yeni)
- `test/data/services/database_service_test.dart` (yeni)

## 1. Şema geçişi (`DatabaseService`) — en dikkatli kısım

Bu, uygulamanın **ilk** şema geçişi. Kullanıcının telefonunda gerçek antrenman verisi var; geçiş hiçbir mevcut
satırı değiştirmemeli ya da silmemeli.

- `schemaVersion = 2`.
- Şema ifadelerini ikiye ayır: mevcut `_schemaStatements` (sürüm 1, **değiştirme**) ve yeni
  `_schemaV2Statements` (ARCHITECTURE §4 "Şema 2"deki iki tablo + index, birebir).
- Yerleşik türleri ekleyen bir yardımcı: `builtinMeasurementTypes` sırasıyla, `position` 0, 1, 2…,
  `builtin_key` = `key`.
- `onCreate` (yeni kurulum): tek transaction'da v1 ifadeleri + v2 ifadeleri + yerleşik türler.
- `onUpgrade(db, oldVersion, newVersion)`: `if (oldVersion < 2)` → tek transaction'da v2 ifadeleri + yerleşik
  türler. İleride 3, 4… için aynı `if (oldVersion < N)` deseni kullanılacak şekilde yaz; kısa bir yorumla açıkla.
- `OpenDatabaseOptions`'a `onUpgrade` ekle.

## 2. `SqliteMeasurementRepository` (yeni)

- Kurucu: `SqliteMeasurementRepository(DatabaseService service)` (`SqliteWorkoutRepository` ile aynı desen;
  önce onu oku ve stilini taklit et: `_db`, `_cleanText`, transaction'lar).
- Arayüzdeki her kuralı uygula. Notlar:
  - `createMeasurementType`: `position` = mevcut en büyük + 1; `builtin_key` NULL. Ad çakışması
    `normalizeForSearch` ile Dart tarafında kontrol edilir (veritabanının `COLLATE NOCASE`'i Türkçe harfleri bilmez).
  - `deleteMeasurementType`: yerleşik türse `ArgumentError`; ölçümleri `ON DELETE CASCADE` ile silinir.
  - `getMeasurementSummaries`: her tür için son iki ölçüm (`measured_at DESC, id DESC`).
  - `exportMeasurements` / `importMeasurements`: arayüzdeki kurallar. İçe aktarma tek transaction; önce tüm
    girdiyi doğrula, sonra yaz.

## 3. `FakeMeasurementRepository` (yeni, `test/fakes/`)

Bellekte, aynı kurallar; kurulduğunda yerleşik türleri `builtinMeasurementTypes` sırasıyla içerir (gerçek
veritabanı gibi). `FakeWorkoutRepository`'nin stilini taklit et; silinen id'ler tekrar kullanılmaz.

## 4. Sözleşme testleri

`test/data/repositories/measurement_repository_contract.dart`: `workout_repository_contract.dart` gibi bir
`runMeasurementRepositoryContractTests(name, create, {dispose})` fonksiyonu; SQLite ve Fake test dosyaları bunu
çağırır (SQLite için `sqflite_common_ffi`, `inMemoryDatabasePath` — mevcut `sqlite_workout_repository_test.dart`'a bak).

Kapsa: yerleşik 10 tür doğru sırada; özel tür ekleme (sona gelir, kırpılır, boş ad/birim → `ArgumentError`,
"sağ KOL" / "SAG KOL" → `DuplicateMeasurementTypeException`); yerleşik türü silme → `ArgumentError`; özel türü silmek
ölçümlerini de siler; ölçüm ekleme/güncelleme/silme; değer <= 0 → `ArgumentError`; olmayan tür → `ArgumentError`;
`getMeasurements` sırası; `getMeasurementSummaries` (ölçümsüz tür `latest == null`; iki ölçümde `change`);
export (yalnız özel türler, ölçümler sıralı); import (eşleşme adla, Türkçe harf farkı dahil; bilinmeyen tür
oluşturulur; aynı zamanlı ölçüm atlanır, ikinci içe aktarma 0 ekler; geçersiz değerde hiçbir şey yazılmaz).

## 5. Geçiş testi (`test/data/services/database_service_test.dart`) — zorunlu

`Directory.systemTemp.createTemp()` içinde gerçek bir dosya yolu kullan (bellek içi veritabanı kapanınca kaybolur):

1. `databaseFactoryFfi.openDatabase(path, options: OpenDatabaseOptions(version: 1, onCreate: ...))` ile **sürüm 1**
   şemasını elle kur (ifadeleri `DatabaseService`'ten kopyala ya da `@visibleForTesting` bir getter ile al),
   `PRAGMA foreign_keys = ON`, bir hareket + antrenman + workout_exercise + set ekle, kapat.
2. Aynı yolu `DatabaseService(factory: databaseFactoryFfi, path: path)` ile aç.
3. Doğrula: `PRAGMA user_version` 2; eski satırlar aynen duruyor (ve `SqliteWorkoutRepository` ile okunabiliyor);
   `measurement_types` 10 yerleşik türü doğru sırada içeriyor; `SqliteMeasurementRepository` ile ölçüm eklenebiliyor.
4. Ayrıca: sıfırdan açılan veritabanı da sürüm 2 ve 10 yerleşik türle geliyor. Sonra geçici klasörü sil.

## 6. `main.dart`

`SqliteMeasurementRepository`'yi **aynı** `DatabaseService` örneğiyle oluştur (iki ayrı bağlantı açma) ve
`Provider<MeasurementRepository>` olarak ekle; `ExerciseTrackerApp`'e `required this.measurementRepository`.
`test/widget_test.dart`'ı buna göre güncelle (`FakeMeasurementRepository`).

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
