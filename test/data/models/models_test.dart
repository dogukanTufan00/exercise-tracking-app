import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MuscleGroup', () {
    test('fromName bilinen değeri çevirir', () {
      expect(MuscleGroup.fromName('chest'), MuscleGroup.chest);
    });

    test('fromName bilinmeyen değerde other döner', () {
      expect(MuscleGroup.fromName('kardiyo'), MuscleGroup.other);
    });
  });

  group('AppThemeId', () {
    test('fromName null ya da bilinmeyen değerde varsayılanı döner', () {
      expect(AppThemeId.fromName(null), AppThemeId.defaultTheme);
      expect(AppThemeId.fromName('pembe'), AppThemeId.defaultTheme);
      expect(AppThemeId.fromName('redBlack'), AppThemeId.redBlack);
    });
  });

  group('toMap / fromMap', () {
    test('Exercise gidiş-dönüş', () {
      const exercise = Exercise(
        id: 1,
        name: 'Bench Press',
        muscleGroup: MuscleGroup.chest,
      );
      expect(Exercise.fromMap(exercise.toMap()), exercise);
    });

    test('Workout gidiş-dönüş, başlıklı ve başlıksız', () {
      final withTitle = Workout(
        id: 1,
        startedAt: DateTime(2026, 10, 17, 18, 30),
        title: 'Upper',
      );
      final withoutTitle = Workout(id: 2, startedAt: DateTime(2026, 10, 15));
      expect(Workout.fromMap(withTitle.toMap()), withTitle);
      expect(Workout.fromMap(withoutTitle.toMap()), withoutTitle);
    });

    test('WorkoutExercise gidiş-dönüş', () {
      const workoutExercise = WorkoutExercise(
        id: 3,
        workoutId: 1,
        exerciseId: 1,
        position: 0,
        note: '2. sette formum bozuldu',
      );
      expect(WorkoutExercise.fromMap(workoutExercise.toMap()), workoutExercise);
    });

    test('ExerciseSet gidiş-dönüş', () {
      const set = ExerciseSet(
        id: 5,
        workoutExerciseId: 3,
        setNumber: 1,
        weightKg: 62.5,
        reps: 8,
      );
      expect(ExerciseSet.fromMap(set.toMap()), set);
    });

    test('ExerciseSet SQLite int döndürse de ağırlığı double okur', () {
      final set = ExerciseSet.fromMap({
        'id': 1,
        'workout_exercise_id': 1,
        'set_number': 1,
        'weight_kg': 60,
        'reps': 10,
      });
      expect(set.weightKg, 60.0);
    });
  });

  group('copyWith', () {
    final workout = Workout(id: 1, startedAt: DateTime(2026), title: 'Upper');

    test('verilmeyen alanlar korunur', () {
      expect(workout.copyWith(id: 2).title, 'Upper');
    });

    test('null verilen başlık silinir', () {
      expect(workout.copyWith(title: null).title, isNull);
    });

    test('WorkoutExercise notu null ile silinir, verilmezse korunur', () {
      const we = WorkoutExercise(
        id: 1,
        workoutId: 1,
        exerciseId: 1,
        position: 0,
        note: 'kolay geldi',
      );
      expect(we.copyWith(position: 1).note, 'kolay geldi');
      expect(we.copyWith(note: null).note, isNull);
    });
  });
}
