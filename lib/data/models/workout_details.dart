import 'exercise.dart';
import 'exercise_set.dart';
import 'muscle_group.dart';
import 'workout.dart';
import 'workout_exercise.dart';

// Bu dosyadaki sınıflar veritabanında tablo değildir; Repository'nin birden çok
// tabloyu birleştirip ekranlara hazır hale getirdiği "okuma modelleri"dir.

/// Geçmiş listesindeki tek bir antrenman kartı için gereken bilgiler.
class WorkoutSummary {
  const WorkoutSummary({
    required this.workout,
    required this.exerciseCount,
    required this.setCount,
    required this.muscleGroups,
  });

  final Workout workout;
  final int exerciseCount;
  final int setCount;

  /// Antrenmanda çalışılan kas grupları; her grup bir kez, ilk görülme sırasıyla.
  final List<MuscleGroup> muscleGroups;
}

/// Antrenmandaki bir hareket, katalog bilgisi ve setleriyle birlikte.
class WorkoutExerciseDetail {
  const WorkoutExerciseDetail({
    required this.workoutExercise,
    required this.exercise,
    required this.sets,
  });

  final WorkoutExercise workoutExercise;
  final Exercise exercise;

  /// [ExerciseSet.setNumber] sırasına göre.
  final List<ExerciseSet> sets;
}

/// Antrenman ekranının ihtiyaç duyduğu her şey.
class WorkoutDetail {
  const WorkoutDetail({
    required this.workout,
    required this.exercises,
  });

  final Workout workout;

  /// [WorkoutExercise.position] sırasına göre.
  final List<WorkoutExerciseDetail> exercises;
}

/// Bir hareketin tek bir antrenmandaki setleri (ilerleme grafiği ve rekorlar için).
class ExerciseSession {
  const ExerciseSession({
    required this.workout,
    required this.sets,
  });

  final Workout workout;

  /// Hareket antrenmana birden çok kez eklendiyse hepsinin setleri:
  /// önce [WorkoutExercise.position], sonra [ExerciseSet.setNumber] sırasıyla. Boş olmaz.
  final List<ExerciseSet> sets;
}
