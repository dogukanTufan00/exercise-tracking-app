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

/// Kullanıcının eklediği bir ölçüm türü (yerleşikler yedeğe yazılmaz). (format 2)
class BackupMeasurementType {
  const BackupMeasurementType({required this.name, required this.unit});

  final String name;
  final String unit;
}

/// Tarihli bir ölçüm. Türüne adıyla başvurulur; tür hedefte yoksa bu ad ve birimle oluşturulur. (format 2)
class BackupMeasurement {
  const BackupMeasurement({
    required this.typeName,
    required this.unit,
    required this.measuredAt,
    required this.value,
  });

  final String typeName;
  final String unit;
  final DateTime measuredAt;
  final double value;
}

/// Tüm yedek: katalog (hiç kullanılmamış hareketler dahil), antrenmanlar ve (format 2'den itibaren) ölçümler.
class BackupData {
  const BackupData({
    required this.exportedAt,
    required this.exercises,
    required this.workouts,
    this.measurementTypes = const [],
    this.measurements = const [],
    this.formatVersion = currentFormatVersion,
  });

  /// JSON biçiminin sürümü. Biçim değişirse artırılır; içe aktarma eski sürümleri tanır.
  /// 1: hareketler ve antrenmanlar. 2: + ölçüm türleri ve ölçümler.
  static const int currentFormatVersion = 2;

  final int formatVersion;
  final DateTime exportedAt;

  /// Ada göre A→Z (normalizeForSearch ile).
  final List<BackupExercise> exercises;

  /// En eskiden en yeniye ([BackupWorkout.startedAt]).
  final List<BackupWorkout> workouts;

  /// Kullanıcının eklediği ölçüm türleri (eklenme sırasıyla). Format 1 yedeklerde boş.
  final List<BackupMeasurementType> measurementTypes;

  /// Ölçümler, en eskiden en yeniye. Format 1 yedeklerde boş.
  final List<BackupMeasurement> measurements;
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
