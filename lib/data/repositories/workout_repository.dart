import '../models/models.dart';

/// Antrenman verilerine tek giriş kapısı.
///
/// ViewModel'ler yalnızca bu arayüzü tanır; verinin SQLite'tan mı yoksa ileride bir
/// sunucudan mı geldiğini bilmez. Uygulamaları: `SqliteWorkoutRepository` (gerçek) ve
/// testlerdeki `FakeWorkoutRepository` (bellekte).
///
/// Ortak kurallar:
/// - Var olmayan bir id ile yapılan güncelleme/silme işlemleri sessizce hiçbir şey yapmaz.
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

  /// Adında [query] geçen hareketler (büyük/küçük harf duyarsız), ada göre A→Z.
  /// [query] boşsa tüm katalog döner.
  Future<List<Exercise>> searchExercises(String query);

  /// Kataloğa yeni hareket ekler.
  ///
  /// Aynı adda (büyük/küçük harf duyarsız) bir hareket zaten varsa
  /// [DuplicateExerciseException] fırlatır. Ad boşsa [ArgumentError] fırlatır.
  Future<Exercise> createExercise(String name, MuscleGroup muscleGroup);

  // -------------------------------------------------- Antrenmandaki hareketler

  /// Katalogdaki bir hareketi antrenmanın sonuna ekler.
  Future<WorkoutExercise> addExerciseToWorkout(int workoutId, int exerciseId);

  /// Hareketin notunu değiştirir; `null` ya da boş metin notu kaldırır.
  Future<void> updateExerciseNote(int workoutExerciseId, String? note);

  /// Hareketi (ve setlerini) antrenmandan kaldırır.
  /// Kalan hareketlerin [WorkoutExercise.position] değerleri 0, 1, 2… olarak yeniden sıralanır.
  Future<void> removeExerciseFromWorkout(int workoutExerciseId);

  // ----------------------------------------------------------------------- Setler

  /// Harekete yeni set ekler; set numarası mevcut en büyük numaranın bir fazlasıdır.
  ///
  /// [weightKg] < 0 ya da [reps] <= 0 ise [ArgumentError] fırlatır.
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
}

/// Katalogda aynı adda bir hareket zaten olduğunda fırlatılır.
class DuplicateExerciseException implements Exception {
  const DuplicateExerciseException(this.name);

  final String name;

  @override
  String toString() => 'DuplicateExerciseException: "$name" zaten katalogda var';
}
