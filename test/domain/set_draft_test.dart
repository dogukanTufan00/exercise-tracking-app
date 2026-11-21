import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/domain/set_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exercise = Exercise(id: 1, name: 'Bench Press', muscleGroup: MuscleGroup.chest);

  WorkoutExerciseDetail entry({ExerciseTarget? target, List<ExerciseSet> sets = const []}) {
    return WorkoutExerciseDetail(
      workoutExercise: WorkoutExercise(
        id: 10,
        workoutId: 5,
        exerciseId: 1,
        position: 0,
        target: target,
      ),
      exercise: exercise,
      sets: sets,
    );
  }

  ExerciseSet set(int number, double kg, int reps) => ExerciseSet(
        id: 100 + number,
        workoutExerciseId: 10,
        setNumber: number,
        weightKg: kg,
        reps: reps,
      );

  test('varsayılan taslak 20 kg × 10', () {
    expect(defaultSetDraft.weightKg, 20);
    expect(defaultSetDraft.reps, 10);
  });

  test('bu antrenmandaki son set en önceliklidir (hedef ve geçen sefer olsa da)', () {
    final result = initialSetDraft(
      entry(
        target: const ExerciseTarget(sets: 3, reps: 8, weightKg: 40),
        sets: [set(1, 50, 6), set(2, 55, 5)],
      ),
      [set(1, 30, 12)],
    );

    expect(result.weightKg, 55);
    expect(result.reps, 5);
  });

  test('set yoksa hedef kullanılır: ağırlık ve tekrar hedeften', () {
    final result = initialSetDraft(
      entry(target: const ExerciseTarget(sets: 3, reps: 8, weightKg: 40)),
      [set(1, 30, 12)],
    );

    expect(result.weightKg, 40);
    expect(result.reps, 8);
  });

  test('hedefte ağırlık yoksa geçen sefer ilk setinin ağırlığı alınır', () {
    final result = initialSetDraft(
      entry(target: const ExerciseTarget(sets: 3, reps: 8)),
      [set(1, 37.5, 12), set(2, 35, 10)],
    );

    expect(result.weightKg, 37.5);
    expect(result.reps, 8);
  });

  test('hedefte ağırlık da geçen sefer de yoksa 20 kg ve hedef tekrar', () {
    final result = initialSetDraft(
      entry(target: const ExerciseTarget(sets: 3, reps: 8)),
      const [],
    );

    expect(result.weightKg, 20);
    expect(result.reps, 8);
  });

  test('hedef yoksa geçen sefer ilk seti kullanılır', () {
    final result = initialSetDraft(entry(), [set(1, 45, 8), set(2, 40, 10)]);

    expect(result.weightKg, 45);
    expect(result.reps, 8);
  });

  test('hiçbiri yoksa varsayılan taslak döner', () {
    final result = initialSetDraft(entry(), const []);

    expect(result.weightKg, defaultSetDraft.weightKg);
    expect(result.reps, defaultSetDraft.reps);
  });
}
