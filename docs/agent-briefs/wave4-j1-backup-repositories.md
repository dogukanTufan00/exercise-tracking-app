# Dalga 4 – Ajan J1: Repository'lerde yedekleme (issue #1)

Önce [ortak kuralları](README.md) oku. Bu görev mevcut kodu **genişletir**: değiştireceğin iki dosyayı baştan sona oku.

## Dokunabileceğin dosyalar

- `lib/data/repositories/sqlite_workout_repository.dart`
- `test/fakes/fake_workout_repository.dart`
- `test/data/repositories/sqlite_workout_repository_test.dart` (yalnızca gerekirse)

## Görev

`WorkoutRepository`'ye iki metot eklendi: `exportBackup()` ve `importBackup(BackupData)`.
Davranışları `lib/data/repositories/workout_repository.dart` içindeki doküman yorumlarında **kesin** olarak tanımlı;
veri sınıfları `lib/data/models/backup_data.dart` içinde. İki metodu **hem** `SqliteWorkoutRepository`'de **hem**
`FakeWorkoutRepository`'de uygula. İkisi de `test/data/repositories/workout_repository_contract.dart` içindeki
`yedekleme` grubunu (ve tüm eski testleri) geçmeli. Sözleşme dosyasını **değiştirme**.

### `exportBackup`
- Katalog: tüm hareketler, `normalizeForSearch(ad)` sonra orijinal ada göre A→Z (mevcut `searchExercises('')` sırasıyla aynı).
- Antrenmanlar: `startedAt` artan, eşitlikte id artan; hareketler `position`, setler `setNumber` sırasıyla.
- `exportedAt: DateTime.now()`.
- SQLite'ta N+1 sorgudan kaçın: antrenmanları, antrenman hareketlerini (katalogla JOIN) ve setleri üç sorguda çek,
  Dart'ta birleştir.

### `importBackup`
1. **Önce doğrula, sonra yaz.** Yazmaya başlamadan tüm yedeği dolaş: kırpılmış hareket adı boşsa, `weightKg < 0`
   ya da `reps <= 0` ise `ArgumentError` fırlat. (Katalog listesi `data.exercises` de doğrulanır.)
2. Katalog eşlemesi: mevcut hareketleri `normalizeForSearch(ad) → Exercise` haritasına al. Önce `data.exercises`,
   sonra antrenmanlardaki hareketler için: haritada yoksa kırpılmış ad + yedekteki kas grubuyla oluştur, haritaya ekle,
   `addedExercises`'ı artır.
3. Antrenmanlar (yedekteki sırayla): mevcut ve bu içe aktarmada eklenen başlangıç zamanları kümesinde `startedAt`
   varsa `skippedWorkouts++` ve atla. Yoksa antrenmanı (başlık kuralı: kırp, boşsa null), hareketlerini
   (`position` 0,1,2…, not kuralı: kırp, boşsa null) ve setlerini (`set_number` 1,2,3…) ekle; `addedWorkouts++`.
4. **SQLite:** 2. ve 3. adımın tamamı tek `db.transaction` içinde, tüm sorgular `txn` ile (mevcut public metotları
   transaction içinden çağırma; gerekirse `DatabaseExecutor` alan private yardımcılar yaz). Başlangıç zamanı
   karşılaştırması `toIso8601String()` metinleriyle yapılır (`started_at` sütunu böyle saklanıyor).
5. **Fake:** doğrulama 1. adımda yapıldığı için yazma aşaması hata vermez; yine de map'lere yazmadan önce tüm
   değişiklikleri hesaplayıp sonra uygula. `DateTime` eşitliği ile karşılaştır.

## Bitti sayılması için

- `flutter analyze lib/data test/data test/fakes` temiz
- `flutter test test/data test/fakes` tamamen geçiyor (SQLite ve Fake için tüm sözleşme testleri, `yedekleme` dahil)
