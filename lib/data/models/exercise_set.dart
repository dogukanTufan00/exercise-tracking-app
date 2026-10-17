/// Bir hareketin tek bir seti: ağırlık ve tekrar.
///
/// Adı `Set` değil, çünkü `Set` Dart'ın yerleşik koleksiyon tipidir.
class ExerciseSet {
  const ExerciseSet({
    required this.id,
    required this.workoutExerciseId,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
  });

  factory ExerciseSet.fromMap(Map<String, Object?> map) {
    return ExerciseSet(
      id: map['id'] as int,
      workoutExerciseId: map['workout_exercise_id'] as int,
      setNumber: map['set_number'] as int,
      // SQLite REAL sütunu tam sayı gibi görünen değerleri int döndürebilir (ör. 60).
      weightKg: (map['weight_kg'] as num).toDouble(),
      reps: map['reps'] as int,
    );
  }

  final int id;
  final int workoutExerciseId;

  /// Hareket içindeki set numarası; 1'den başlar.
  final int setNumber;
  final double weightKg;
  final int reps;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'workout_exercise_id': workoutExerciseId,
      'set_number': setNumber,
      'weight_kg': weightKg,
      'reps': reps,
    };
  }

  ExerciseSet copyWith({
    int? id,
    int? workoutExerciseId,
    int? setNumber,
    double? weightKg,
    int? reps,
  }) {
    return ExerciseSet(
      id: id ?? this.id,
      workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
      setNumber: setNumber ?? this.setNumber,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseSet &&
        other.id == id &&
        other.workoutExerciseId == workoutExerciseId &&
        other.setNumber == setNumber &&
        other.weightKg == weightKg &&
        other.reps == reps;
  }

  @override
  int get hashCode =>
      Object.hash(id, workoutExerciseId, setNumber, weightKg, reps);

  @override
  String toString() => 'ExerciseSet($id, #$setNumber, $weightKg kg x $reps)';
}
