import '../models/models.dart';

/// Antrenman programlarına tek giriş kapısı. Bkz. docs/ARCHITECTURE.md §14.
///
/// Uygulamaları: `SqliteProgramRepository` (gerçek, antrenmanlarla aynı veritabanı) ve testlerdeki
/// `FakeProgramRepository` (bellekte; antrenman başlatmak için bir `FakeWorkoutRepository` ile birlikte çalışır).
///
/// Ortak kurallar:
/// - Adlar kırpılarak saklanır; boş ad → [ArgumentError].
/// - Hedeflerde `sets` ve `reps` 0'dan büyük, `weightKg` (varsa) 0 ya da büyük olmalı; değilse [ArgumentError].
/// - `weekday` `null` ya da 1…7 olmalı; değilse [ArgumentError].
/// - Var olmayan bir id ile güncelleme/silme sessizce hiçbir şey yapmaz; ekleme işlemlerinde üst kayıt
///   (program, gün, hareket) yoksa [ArgumentError].
abstract interface class ProgramRepository {
  // ------------------------------------------------------------------- Programlar

  /// Tüm programlar, oluşturulma sırasıyla.
  Future<List<Program>> getPrograms();

  /// Program ve tüm günleri/hareketleri; yoksa `null`.
  Future<ProgramDetail?> getProgramDetail(int programId);

  /// Etkin programın detayı; etkin program yoksa `null`.
  Future<ProgramDetail?> getActiveProgramDetail();

  /// Yeni program oluşturur. Henüz hiç etkin program yoksa yeni program etkin olur.
  Future<Program> createProgram(String name);

  Future<void> renameProgram(int programId, String name);

  /// Programı etkin yapar; diğerlerinin etkinliği kalkar (en fazla bir etkin program).
  Future<void> setActiveProgram(int programId);

  /// Programı, günlerini ve gün hareketlerini siler. Bu programdan başlatılmış antrenmanlar kalır
  /// (bağlantıları `null` olur). Etkin program silinirse etkin program kalmaz.
  Future<void> deleteProgram(int programId);

  // ----------------------------------------------------------------------- Günler

  /// Programın sonuna yeni gün ekler.
  Future<ProgramDay> addDay(int programId, String name, {int? weekday});

  /// Günün adını ve planlanan gününü değiştirir ([ProgramDay.id] ile bulunur; sıra değişmez).
  Future<void> updateDay(ProgramDay day);

  /// Günü ve hareketlerini siler; kalan günlerin sırası 0, 1, 2… olarak yeniden düzenlenir.
  Future<void> deleteDay(int dayId);

  /// Programın günlerini verilen sıraya koyar. [dayIds] programın tüm günlerini tam olarak bir kez
  /// içermelidir; değilse [ArgumentError].
  Future<void> reorderDays(int programId, List<int> dayIds);

  // ------------------------------------------------------------- Gün hareketleri

  /// Günün sonuna hareket ekler.
  Future<ProgramDayExercise> addDayExercise(int dayId, int exerciseId, ExerciseTarget target);

  Future<void> updateDayExerciseTarget(int dayExerciseId, ExerciseTarget target);

  /// Hareketi günden çıkarır; kalanların sırası yeniden düzenlenir.
  Future<void> removeDayExercise(int dayExerciseId);

  /// Günün hareketlerini verilen sıraya koyar ([reorderDays] ile aynı kural).
  Future<void> reorderDayExercises(int dayId, List<int> dayExerciseIds);

  // ----------------------------------------------------------- Antrenman başlatma

  /// Program gününden yeni bir antrenman oluşturur ve döndürür:
  /// - başlık = gün adı, `programDayId` = [dayId], başlangıç [startedAt] (verilmezse şu an);
  /// - günün hareketleri aynı sırayla eklenir, her birinin hedefi `WorkoutExercise.target`'a **kopyalanır**;
  /// - set eklenmez. Gün yoksa [ArgumentError]. Tek transaction.
  Future<Workout> startWorkoutFromDay(int dayId, {DateTime? startedAt});

  // -------------------------------------------------------------------- Yedekleme

  /// Yedeğe girecek programlar (oluşturulma sırasıyla), hareketlere adla başvurarak.
  Future<List<BackupProgram>> exportPrograms();

  /// Yedekteki programları mevcut verilerle **birleştirir**; eklenen program sayısını döndürür.
  ///
  /// - Adı (`normalizeForSearch`) mevcut bir programınkiyle aynı olan program **atlanır**.
  /// - Hareketler adla eşleşir; bulunamayan hareket yedekteki ad ve kas grubuyla kataloğa eklenir.
  /// - Yedekte etkin işaretli bir program eklenirse ve şu an etkin program yoksa etkin olur; varsa mevcut kalır.
  /// - **Ya hep ya hiç:** geçersiz değer varsa [ArgumentError] ve hiçbir değişiklik kalmaz.
  Future<int> importPrograms(List<BackupProgram> programs);
}
