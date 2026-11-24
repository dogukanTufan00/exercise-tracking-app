import 'dart:async';

import '../models/models.dart';
import '../repositories/workout_repository.dart';
import 'watch_sync_service.dart';

/// [WorkoutRepository] sarmalayıcısı: her başarılı değiştirici çağrıdan sonra saat servisine haber verir
/// (bkz. docs/ARCHITECTURE.md §15.8 madde 2).
///
/// - Antrenman id'si doğrudan bilinen çağrılar (`updateWorkoutTitle`, `deleteWorkout`, `addExerciseToWorkout`)
///   yalnızca o antrenmanı yeniden yayınlatır ([WatchSyncService.workoutChanged]).
/// - Diğer değiştiriciler etkin antrenmanı koşulsuz yeniden yayınlatır ([WatchSyncService.activeWorkoutChanged]).
/// - Okuma metotları ve `createExercise` saate haber vermez.
///
/// Haber beklenmez ([unawaited]); [WatchSyncService] hata fırlatmadığı için çağıranı etkilemez.
/// [_inner] saate haber vermeyen (sarılmamış) bir repository olmalıdır.
class WatchAwareWorkoutRepository implements WorkoutRepository {
  WatchAwareWorkoutRepository(this._inner, this._watchSync);

  final WorkoutRepository _inner;
  final WatchSyncService _watchSync;

  void _workoutChanged(int workoutId) => unawaited(_watchSync.workoutChanged(workoutId));

  void _activeChanged() => unawaited(_watchSync.activeWorkoutChanged());

  // ---------------------------------------------------------------- Antrenmanlar

  @override
  Future<List<WorkoutSummary>> getWorkoutSummaries() => _inner.getWorkoutSummaries();

  @override
  Future<WorkoutDetail?> getWorkoutDetail(int workoutId) => _inner.getWorkoutDetail(workoutId);

  @override
  Future<Workout> createWorkout({String? title, DateTime? startedAt}) async {
    final workout = await _inner.createWorkout(title: title, startedAt: startedAt);
    _activeChanged();
    return workout;
  }

  @override
  Future<void> updateWorkoutTitle(int workoutId, String? title) async {
    await _inner.updateWorkoutTitle(workoutId, title);
    _workoutChanged(workoutId);
  }

  @override
  Future<void> deleteWorkout(int workoutId) async {
    await _inner.deleteWorkout(workoutId);
    _workoutChanged(workoutId);
  }

  // ------------------------------------------------------------- Hareket kataloğu

  @override
  Future<List<Exercise>> searchExercises(String query) => _inner.searchExercises(query);

  @override
  Future<Exercise> createExercise(String name, MuscleGroup muscleGroup) =>
      _inner.createExercise(name, muscleGroup);

  @override
  Future<Exercise> updateExercise(int id, {required String name, required MuscleGroup muscleGroup}) async {
    final exercise = await _inner.updateExercise(id, name: name, muscleGroup: muscleGroup);
    _activeChanged();
    return exercise;
  }

  @override
  Future<void> mergeExercises({required int sourceId, required int targetId}) async {
    await _inner.mergeExercises(sourceId: sourceId, targetId: targetId);
    _activeChanged();
  }

  // -------------------------------------------------- Antrenmandaki hareketler

  @override
  Future<WorkoutExercise> addExerciseToWorkout(int workoutId, int exerciseId) async {
    final workoutExercise = await _inner.addExerciseToWorkout(workoutId, exerciseId);
    _workoutChanged(workoutId);
    return workoutExercise;
  }

  @override
  Future<void> updateExerciseNote(int workoutExerciseId, String? note) async {
    await _inner.updateExerciseNote(workoutExerciseId, note);
    _activeChanged();
  }

  @override
  Future<void> removeExerciseFromWorkout(int workoutExerciseId) async {
    await _inner.removeExerciseFromWorkout(workoutExerciseId);
    _activeChanged();
  }

  @override
  Future<void> changeWorkoutExercise(int workoutExerciseId, int exerciseId) async {
    await _inner.changeWorkoutExercise(workoutExerciseId, exerciseId);
    _activeChanged();
  }

  // ----------------------------------------------------------------------- Setler

  @override
  Future<ExerciseSet> addSet(
    int workoutExerciseId, {
    required double weightKg,
    required int reps,
  }) async {
    final set = await _inner.addSet(workoutExerciseId, weightKg: weightKg, reps: reps);
    _activeChanged();
    return set;
  }

  @override
  Future<void> updateSet(ExerciseSet set) async {
    await _inner.updateSet(set);
    _activeChanged();
  }

  @override
  Future<void> deleteSet(int setId) async {
    await _inner.deleteSet(setId);
    _activeChanged();
  }

  // ---------------------------------------------------------------- "Geçen sefer"

  @override
  Future<List<ExerciseSet>> getPreviousSets(
    int exerciseId, {
    required int beforeWorkoutId,
  }) =>
      _inner.getPreviousSets(exerciseId, beforeWorkoutId: beforeWorkoutId);

  // ------------------------------------------------------------------ İlerleme

  @override
  Future<List<ExerciseSession>> getExerciseHistory(int exerciseId) =>
      _inner.getExerciseHistory(exerciseId);

  // ------------------------------------------------------------ Yedekleme

  @override
  Future<BackupData> exportBackup() => _inner.exportBackup();

  @override
  Future<ImportResult> importBackup(BackupData data) async {
    final result = await _inner.importBackup(data);
    _activeChanged();
    return result;
  }

  @override
  Future<void> setWorkoutFinishedAt(int workoutId, DateTime? finishedAt) {
    // TODO(dalga 16, CB): uygula.
    throw UnimplementedError();
  }
}
