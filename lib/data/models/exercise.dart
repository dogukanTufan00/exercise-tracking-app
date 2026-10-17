import 'muscle_group.dart';

/// Hareket kataloğundaki bir hareket (ör. "Bench Press").
///
/// Her hareket katalogda bir kez bulunur; antrenmanlarda [WorkoutExercise] ile kullanılır.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
  });

  factory Exercise.fromMap(Map<String, Object?> map) {
    return Exercise(
      id: map['id'] as int,
      name: map['name'] as String,
      muscleGroup: MuscleGroup.fromName(map['muscle_group'] as String),
    );
  }

  final int id;
  final String name;
  final MuscleGroup muscleGroup;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'muscle_group': muscleGroup.name,
    };
  }

  Exercise copyWith({int? id, String? name, MuscleGroup? muscleGroup}) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Exercise &&
        other.id == id &&
        other.name == name &&
        other.muscleGroup == muscleGroup;
  }

  @override
  int get hashCode => Object.hash(id, name, muscleGroup);

  @override
  String toString() => 'Exercise($id, $name, ${muscleGroup.name})';
}
