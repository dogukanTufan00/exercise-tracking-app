import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/watch/watch_protocol.dart';
import 'package:exercise_tracking_app/data/watch/watch_snapshot_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_workout_repository.dart';

void main() {
  late FakeWorkoutRepository repo;
  late Exercise bench;
  late Exercise squat;

  String fallback(DateTime startedAt) => 'Tarih ${startedAt.day}';

  setUp(() async {
    repo = FakeWorkoutRepository();
    bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    squat = await repo.createExercise('Squat', MuscleGroup.legs);
  });

  test('antrenman yoksa null döner', () async {
    final result = await buildWatchSnapshot(
      repo,
      999,
      appliedEventIds: const [],
      fallbackTitle: fallback,
    );

    expect(result, isNull);
  });

  test('hareketler position sırasıyla gelir ve kimlikler doğrudur', () async {
    final workout = await repo.createWorkout(
      title: 'Push A',
      startedAt: DateTime(2026, 11, 21, 18, 30),
    );
    final first = await repo.addExerciseToWorkout(workout.id, squat.id);
    final second = await repo.addExerciseToWorkout(workout.id, bench.id);

    final snapshot = await buildWatchSnapshot(
      repo,
      workout.id,
      appliedEventIds: const ['a', 'b'],
      fallbackTitle: fallback,
    );

    expect(snapshot, isNotNull);
    final s = snapshot!;
    expect(s.protocol, watchProtocolVersion);
    expect(s.workoutId, workout.id);
    expect(s.title, 'Push A');
    expect(s.startedAt, DateTime(2026, 11, 21, 18, 30));
    expect(s.appliedEventIds, ['a', 'b']);
    expect(s.exercises.map((e) => e.workoutExerciseId), [first.id, second.id]);
    expect(s.exercises.map((e) => e.name), ['Squat', 'Bench Press']);
  });

  test('başlıksız antrenmanda fallbackTitle kullanılır', () async {
    final startedAt = DateTime(2026, 11, 20, 9);
    final workout = await repo.createWorkout(startedAt: startedAt);

    final snapshot = await buildWatchSnapshot(
      repo,
      workout.id,
      appliedEventIds: const [],
      fallbackTitle: fallback,
    );

    expect(snapshot!.title, 'Tarih 20');
  });

  test('taslak kuralı uygulanır: geçen seferin ilk seti', () async {
    final previous = await repo.createWorkout(startedAt: DateTime(2026, 10, 1, 18));
    final prevWe = await repo.addExerciseToWorkout(previous.id, bench.id);
    await repo.addSet(prevWe.id, weightKg: 37.5, reps: 10);
    await repo.addSet(prevWe.id, weightKg: 35, reps: 8);

    final workout = await repo.createWorkout(startedAt: DateTime(2026, 11, 21, 18));
    await repo.addExerciseToWorkout(workout.id, bench.id);

    final snapshot = await buildWatchSnapshot(
      repo,
      workout.id,
      appliedEventIds: const [],
      fallbackTitle: fallback,
    );

    final exercise = snapshot!.exercises.single;
    expect(exercise.draft, const WatchSetValue(weightKg: 37.5, reps: 10));
    expect(
      exercise.previous,
      const [WatchSetValue(weightKg: 37.5, reps: 10), WatchSetValue(weightKg: 35, reps: 8)],
    );
    expect(exercise.sets, isEmpty);
    expect(exercise.target, isNull);
  });

  test('bu antrenmandaki sets ve taslak son set olur', () async {
    final workout = await repo.createWorkout(startedAt: DateTime(2026, 11, 21, 18));
    final we = await repo.addExerciseToWorkout(workout.id, bench.id);
    await repo.addSet(we.id, weightKg: 50, reps: 6);
    final last = await repo.addSet(we.id, weightKg: 55, reps: 4);

    final snapshot = await buildWatchSnapshot(
      repo,
      workout.id,
      appliedEventIds: const [],
      fallbackTitle: fallback,
    );

    final exercise = snapshot!.exercises.single;
    expect(exercise.sets.map((s) => s.setNumber), [1, 2]);
    expect(exercise.sets.last, WatchSet(id: last.id, setNumber: 2, weightKg: 55, reps: 4));
    expect(exercise.draft, const WatchSetValue(weightKg: 55, reps: 4));
  });
}
