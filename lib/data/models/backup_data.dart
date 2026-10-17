import 'muscle_group.dart';

// Yedekleme (dışa/içe aktarma) için veritabanı kimliklerinden bağımsız veri sınıfları.
// Hareketlere id ile değil adla başvurulur; böylece yedek başka bir telefona,
// farklı id'lere sahip bir veritabanına sorunsuz yüklenebilir.

/// Katalogdaki bir hareket.
class BackupExercise {
  const BackupExercise({required this.name, required this.muscleGroup});

  final String name;
  final MuscleGroup muscleGroup;
}

/// Bir set. Set numarası, listedeki sırasından gelir (1'den başlar).
class BackupSet {
  const BackupSet({required this.weightKg, required this.reps});

  final double weightKg;
  final int reps;
}

/// Antrenmandaki bir hareket: adı, kas grubu, notu ve setleri (sırasıyla).
class BackupWorkoutExercise {
  const BackupWorkoutExercise({
    required this.exerciseName,
    required this.muscleGroup,
    required this.sets,
    this.note,
  });

  final String exerciseName;

  /// Hareket hedef katalogda yoksa bu kas grubuyla oluşturulur.
  final MuscleGroup muscleGroup;
  final String? note;
  final List<BackupSet> sets;
}

/// Bir antrenman ve hareketleri (sırasıyla).
class BackupWorkout {
  const BackupWorkout({
    required this.startedAt,
    required this.exercises,
    this.title,
  });

  final DateTime startedAt;
  final String? title;
  final List<BackupWorkoutExercise> exercises;
}

/// Tüm yedek: katalog (hiç kullanılmamış hareketler dahil) ve antrenmanlar.
class BackupData {
  const BackupData({
    required this.exportedAt,
    required this.exercises,
    required this.workouts,
    this.formatVersion = currentFormatVersion,
  });

  /// JSON biçiminin sürümü. Biçim değişirse artırılır; içe aktarma eski sürümleri tanır.
  static const int currentFormatVersion = 1;

  final int formatVersion;
  final DateTime exportedAt;

  /// Ada göre A→Z (normalizeForSearch ile).
  final List<BackupExercise> exercises;

  /// En eskiden en yeniye ([BackupWorkout.startedAt]).
  final List<BackupWorkout> workouts;
}

/// İçe aktarmanın özeti; kullanıcıya gösterilir.
class ImportResult {
  const ImportResult({
    required this.addedWorkouts,
    required this.skippedWorkouts,
    required this.addedExercises,
  });

  final int addedWorkouts;

  /// Aynı başlangıç zamanına sahip bir antrenman zaten olduğu için atlananlar.
  final int skippedWorkouts;
  final int addedExercises;

  @override
  bool operator ==(Object other) {
    return other is ImportResult &&
        other.addedWorkouts == addedWorkouts &&
        other.skippedWorkouts == skippedWorkouts &&
        other.addedExercises == addedExercises;
  }

  @override
  int get hashCode => Object.hash(addedWorkouts, skippedWorkouts, addedExercises);

  @override
  String toString() =>
      'ImportResult(added: $addedWorkouts, skipped: $skippedWorkouts, exercises: $addedExercises)';
}
