import '../../domain/set_draft.dart';
import '../repositories/workout_repository.dart';
import 'watch_protocol.dart';

/// Bir antrenmanın saate gönderilecek anlık durumunu (protokol sürüm 1) oluşturur.
///
/// Antrenman yoksa `null`. Hareketler `position` sırasıyla gelir; her hareketin taslağı
/// [initialSetDraft] ile, "geçen sefer" setleri ise `beforeWorkoutId` ile hesaplanır.
/// Başlık yoksa [fallbackTitle] ile başlangıç tarihinden üretilir.
Future<WatchSnapshot?> buildWatchSnapshot(
  WorkoutRepository repository,
  int workoutId, {
  required List<String> appliedEventIds,
  required String Function(DateTime startedAt) fallbackTitle,
}) async {
  final detail = await repository.getWorkoutDetail(workoutId);
  if (detail == null) return null;

  final exercises = <WatchExercise>[];
  for (final entry in detail.exercises) {
    final previous = await repository.getPreviousSets(
      entry.exercise.id,
      beforeWorkoutId: workoutId,
    );
    final draft = initialSetDraft(entry, previous);
    final target = entry.workoutExercise.target;

    exercises.add(
      WatchExercise(
        workoutExerciseId: entry.workoutExercise.id,
        name: entry.exercise.name,
        target: target == null
            ? null
            : WatchTarget(
                sets: target.sets,
                reps: target.reps,
                weightKg: target.weightKg,
              ),
        sets: [
          for (final set in entry.sets)
            WatchSet(
              id: set.id,
              setNumber: set.setNumber,
              weightKg: set.weightKg,
              reps: set.reps,
            ),
        ],
        draft: WatchSetValue(weightKg: draft.weightKg, reps: draft.reps),
        previous: [
          for (final set in previous)
            WatchSetValue(weightKg: set.weightKg, reps: set.reps),
        ],
      ),
    );
  }

  final startedAt = detail.workout.startedAt;
  return WatchSnapshot(
    workoutId: workoutId,
    title: detail.workout.title ?? fallbackTitle(startedAt),
    startedAt: startedAt,
    appliedEventIds: appliedEventIds,
    exercises: exercises,
  );
}
