import '../models/models.dart';

/// Antrenman verilerine tek giriş kapısı.
///
/// ViewModel'ler yalnızca bu arayüzü tanır; verinin SQLite'tan mı yoksa ileride bir
/// sunucudan mı geldiğini bilmez. Uygulamaları: `SqliteWorkoutRepository` (gerçek) ve
/// testlerdeki `FakeWorkoutRepository` (bellekte).
///
/// Ortak kurallar:
/// - Var olmayan bir id ile yapılan güncelleme/silme işlemleri sessizce hiçbir şey yapmaz.
///   Ekleme işlemlerinde ise üst kayıt (antrenman, hareket) yoksa [ArgumentError] fırlatılır.
/// - Boş ya da yalnızca boşluktan oluşan metinler (başlık, not) `null` olarak saklanır;
///   metinlerin başındaki/sonundaki boşluklar kırpılır.
abstract interface class WorkoutRepository {
  // ---------------------------------------------------------------- Antrenmanlar

  /// Tüm antrenmanların özetleri, en yeniden en eskiye ([Workout.startedAt]).
  Future<List<WorkoutSummary>> getWorkoutSummaries();

  /// Bir antrenmanın tüm detayı; antrenman yoksa `null`.
  Future<WorkoutDetail?> getWorkoutDetail(int workoutId);

  /// Yeni bir antrenman oluşturur. [startedAt] verilmezse şu anki zaman kullanılır.
  Future<Workout> createWorkout({String? title, DateTime? startedAt});

  /// Başlığı değiştirir; `null` ya da boş metin başlığı kaldırır.
  Future<void> updateWorkoutTitle(int workoutId, String? title);

  /// Antrenmanı, içindeki hareketleri ve setleri siler. Katalogdaki hareketler kalır.
  Future<void> deleteWorkout(int workoutId);

  // ------------------------------------------------------------- Hareket kataloğu

  /// Adının normalleştirilmiş hali, [query]'nin normalleştirilmiş halini içeren hareketler.
  /// Normalleştirme için `normalizeForSearch` (lib/data/utils/text_normalizer.dart) kullanılır;
  /// böylece "sinav" araması "Şınav"ı bulur. `%` ve `_` gibi karakterler özel anlam taşımaz.
  ///
  /// Sıralama: normalleştirilmiş ada göre A→Z, eşitlikte orijinal ada göre.
  /// [query] boşsa (ya da yalnızca boşluksa) tüm katalog döner.
  Future<List<Exercise>> searchExercises(String query);

  /// Kataloğa yeni hareket ekler. Ad kırpılarak saklanır.
  ///
  /// Normalleştirilmiş adı (`normalizeForSearch`) mevcut bir hareketinkiyle aynıysa
  /// [DuplicateExerciseException] fırlatır ("Şınav" ile "SINAV" aynı sayılır).
  /// Ad boşsa [ArgumentError] fırlatır.
  Future<Exercise> createExercise(String name, MuscleGroup muscleGroup);

  /// Katalogdaki bir hareketin adını ve kas grubunu değiştirir; güncellenmiş hareketi döndürür.
  ///
  /// Ad kırpılarak saklanır; boşsa [ArgumentError]. Normalleştirilmiş adı (`normalizeForSearch`)
  /// **başka** bir hareketinkiyle aynıysa [DuplicateExerciseException] (hareketin kendi adının
  /// büyük/küçük harfini değiştirmek serbesttir: "bench press" → "Bench Press"). Hareket yoksa [ArgumentError].
  /// Değişiklik hareketin tüm geçmişine yansır.
  Future<Exercise> updateExercise(int id, {required String name, required MuscleGroup muscleGroup});

  /// Aynı hareketin iki kaydını birleştirir (#12): [sourceId]'nin tüm antrenman kayıtları ve program günü
  /// hareketleri [targetId]'ye taşınır, ardından [sourceId] katalogdan silinir. Tek transaction.
  /// [targetId]'nin adı ve kas grubu değişmez. İki id aynıysa ya da biri yoksa [ArgumentError].
  Future<void> mergeExercises({required int sourceId, required int targetId});

  // -------------------------------------------------- Antrenmandaki hareketler

  /// Katalogdaki bir hareketi antrenmanın sonuna ekler.
  ///
  /// Antrenman ya da hareket yoksa [ArgumentError] fırlatır.
  Future<WorkoutExercise> addExerciseToWorkout(int workoutId, int exerciseId);

  /// Hareketin notunu değiştirir; `null` ya da boş metin notu kaldırır.
  Future<void> updateExerciseNote(int workoutExerciseId, String? note);

  /// Hareketi (ve setlerini) antrenmandan kaldırır.
  /// Kalan hareketlerin [WorkoutExercise.position] değerleri 0, 1, 2… olarak yeniden sıralanır.
  Future<void> removeExerciseFromWorkout(int workoutExerciseId);

  /// Antrenmandaki kaydın hareketini [exerciseId] ile değiştirir (#11): yanlış seçilmiş hareket düzeltilir.
  /// Setler, not, sıra ve hedef aynen kalır; yalnızca bu antrenman değişir (katalog değişmez).
  /// Kayıt ya da hareket yoksa [ArgumentError].
  Future<void> changeWorkoutExercise(int workoutExerciseId, int exerciseId);

  // ----------------------------------------------------------------------- Setler

  /// Harekete yeni set ekler; set numarası mevcut en büyük numaranın bir fazlasıdır.
  ///
  /// [weightKg] < 0 ya da [reps] <= 0 ise, ya da [workoutExerciseId] yoksa [ArgumentError] fırlatır.
  Future<ExerciseSet> addSet(
    int workoutExerciseId, {
    required double weightKg,
    required int reps,
  });

  /// Setin ağırlık ve tekrarını günceller ([ExerciseSet.id] ile bulunur).
  /// [addSet] ile aynı doğrulama kuralları geçerlidir.
  Future<void> updateSet(ExerciseSet set);

  /// Seti siler; aynı hareketin kalan setleri 1, 2, 3… olarak yeniden numaralanır.
  Future<void> deleteSet(int setId);

  // ---------------------------------------------------------------- "Geçen sefer"

  /// [exerciseId] hareketinin, [beforeWorkoutId] antrenmanından önce başlamış en son
  /// antrenmandaki setleri (set numarası sırasıyla). Böyle bir antrenman yoksa boş liste.
  Future<List<ExerciseSet>> getPreviousSets(
    int exerciseId, {
    required int beforeWorkoutId,
  });

  // ------------------------------------------------------------------ İlerleme

  /// [exerciseId] hareketinin yapıldığı tüm antrenmanlar, en eskiden en yeniye
  /// ([Workout.startedAt], eşitlikte id sırası). Hareketin hiç seti olmayan antrenmanlar atlanır.
  Future<List<ExerciseSession>> getExerciseHistory(int exerciseId);

  // ------------------------------------------------------------ Yedekleme

  /// Tüm veriyi yedek olarak döndürür ([BackupData.exportedAt] = şu an).
  ///
  /// Katalog: tüm hareketler (hiç kullanılmamışlar dahil), `normalizeForSearch` ile ada göre A→Z.
  /// Antrenmanlar: [Workout.startedAt]'e göre en eskiden en yeniye (eşitlikte id sırası);
  /// içlerinde hareketler `position`, setler `setNumber` sırasıyla.
  Future<BackupData> exportBackup();

  /// Yedeği mevcut verilerle **birleştirir**; mevcut hiçbir veri silinmez ya da değişmez.
  ///
  /// - [BackupWorkout.startedAt] değeri mevcut bir antrenmanınkiyle (ya da bu içe aktarmada daha önce
  ///   eklenen bir antrenmanınkiyle) birebir aynıysa o antrenman **atlanır**.
  /// - Hareketler `normalizeForSearch(ad)` ile katalogda aranır; bulunamayanlar yedekteki ad ve kas
  ///   grubuyla oluşturulur ([BackupData.exercises] listesindekiler dahil).
  /// - Başlık ve not metinleri diğer metotlardaki kurallarla saklanır (kırpılır, boşsa null).
  /// - **Ya hep ya hiç:** geçersiz bir değer (boş hareket adı, ağırlık < 0, tekrar <= 0) varsa
  ///   [ArgumentError] fırlatılır ve veritabanında hiçbir değişiklik kalmaz.
  Future<ImportResult> importBackup(BackupData data);
}

/// Katalogda aynı adda bir hareket zaten olduğunda fırlatılır.
class DuplicateExerciseException implements Exception {
  const DuplicateExerciseException(this.name);

  final String name;

  @override
  String toString() => 'DuplicateExerciseException: "$name" zaten katalogda var';
}
