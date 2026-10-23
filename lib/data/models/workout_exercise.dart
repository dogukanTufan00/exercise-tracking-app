import 'program.dart';

/// copyWith içinde "bu alan verilmedi" ile "bu alan null yapılsın"ı ayırt etmek için kullanılır.
const Object _unset = Object();

/// Bir antrenmanda yapılan bir hareket: hangi antrenman, hangi katalog hareketi, kaçıncı sırada ve notu.
class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.position,
    this.note,
    this.target,
  });

  factory WorkoutExercise.fromMap(Map<String, Object?> map) {
    return WorkoutExercise(
      id: map['id'] as int,
      workoutId: map['workout_id'] as int,
      exerciseId: map['exercise_id'] as int,
      position: map['position'] as int,
      note: map['note'] as String?,
      target: map['target_sets'] == null
          ? null
          : ExerciseTarget(
              sets: map['target_sets'] as int,
              reps: map['target_reps'] as int,
              weightKg: (map['target_weight_kg'] as num?)?.toDouble(),
            ),
    );
  }

  final int id;
  final int workoutId;
  final int exerciseId;

  /// Antrenman içindeki sıra; 0'dan başlar.
  final int position;

  /// Hareket bitince yazılan serbest not (ör. "2. sette formum bozuldu").
  final String? note;

  /// Programdan başlatılan antrenmanda, başlatma anındaki hedefin kopyası (şema 3); yoksa `null`.
  /// Program sonradan değişse de bu antrenmanın hedefi değişmez.
  final ExerciseTarget? target;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'position': position,
      'note': note,
      'target_sets': target?.sets,
      'target_reps': target?.reps,
      'target_weight_kg': target?.weightKg,
    };
  }

  /// [note] için `null` geçmek notu siler; hiç geçmemek mevcut notu korur.
  WorkoutExercise copyWith({
    int? id,
    int? workoutId,
    int? exerciseId,
    int? position,
    Object? note = _unset,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      note: identical(note, _unset) ? this.note : note as String?,
      target: target,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutExercise &&
        other.id == id &&
        other.workoutId == workoutId &&
        other.exerciseId == exerciseId &&
        other.position == position &&
        other.note == note &&
        other.target == target;
  }

  @override
  int get hashCode => Object.hash(id, workoutId, exerciseId, position, note, target);

  @override
  String toString() =>
      'WorkoutExercise($id, workout: $workoutId, exercise: $exerciseId, #$position)';
}
