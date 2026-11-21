import 'dart:async';

import '../models/models.dart';
import '../repositories/program_repository.dart';
import 'watch_sync_service.dart';

/// [ProgramRepository] sarmalayıcısı: her başarılı değiştirici çağrıdan sonra etkin programı saate yeniden
/// yayınlatır ([WatchSyncService.programChanged], bkz. docs/ARCHITECTURE.md §15.8 madde 2).
///
/// `startWorkoutFromDay` saate haber vermez: yeni antrenmanın etkinliğini Antrenman ekranı belirler.
/// Okuma metotları yalnızca iletilir. [_inner] saate haber vermeyen (sarılmamış) bir repository olmalıdır.
class WatchAwareProgramRepository implements ProgramRepository {
  WatchAwareProgramRepository(this._inner, this._watchSync);

  final ProgramRepository _inner;
  final WatchSyncService _watchSync;

  void _programChanged() => unawaited(_watchSync.programChanged());

  // ------------------------------------------------------------------- Programlar

  @override
  Future<List<Program>> getPrograms() => _inner.getPrograms();

  @override
  Future<ProgramDetail?> getProgramDetail(int programId) => _inner.getProgramDetail(programId);

  @override
  Future<ProgramDetail?> getActiveProgramDetail() => _inner.getActiveProgramDetail();

  @override
  Future<Program> createProgram(String name) async {
    final program = await _inner.createProgram(name);
    _programChanged();
    return program;
  }

  @override
  Future<void> renameProgram(int programId, String name) async {
    await _inner.renameProgram(programId, name);
    _programChanged();
  }

  @override
  Future<void> setActiveProgram(int programId) async {
    await _inner.setActiveProgram(programId);
    _programChanged();
  }

  @override
  Future<void> deleteProgram(int programId) async {
    await _inner.deleteProgram(programId);
    _programChanged();
  }

  // ----------------------------------------------------------------------- Günler

  @override
  Future<ProgramDay> addDay(int programId, String name, {int? weekday}) async {
    final day = await _inner.addDay(programId, name, weekday: weekday);
    _programChanged();
    return day;
  }

  @override
  Future<void> updateDay(ProgramDay day) async {
    await _inner.updateDay(day);
    _programChanged();
  }

  @override
  Future<void> deleteDay(int dayId) async {
    await _inner.deleteDay(dayId);
    _programChanged();
  }

  @override
  Future<void> reorderDays(int programId, List<int> dayIds) async {
    await _inner.reorderDays(programId, dayIds);
    _programChanged();
  }

  // ------------------------------------------------------------- Gün hareketleri

  @override
  Future<ProgramDayExercise> addDayExercise(int dayId, int exerciseId, ExerciseTarget target) async {
    final dayExercise = await _inner.addDayExercise(dayId, exerciseId, target);
    _programChanged();
    return dayExercise;
  }

  @override
  Future<void> updateDayExerciseTarget(int dayExerciseId, ExerciseTarget target) async {
    await _inner.updateDayExerciseTarget(dayExerciseId, target);
    _programChanged();
  }

  @override
  Future<void> removeDayExercise(int dayExerciseId) async {
    await _inner.removeDayExercise(dayExerciseId);
    _programChanged();
  }

  @override
  Future<void> reorderDayExercises(int dayId, List<int> dayExerciseIds) async {
    await _inner.reorderDayExercises(dayId, dayExerciseIds);
    _programChanged();
  }

  // ----------------------------------------------------------- Antrenman başlatma

  @override
  Future<Workout> startWorkoutFromDay(int dayId, {DateTime? startedAt}) =>
      _inner.startWorkoutFromDay(dayId, startedAt: startedAt);

  // -------------------------------------------------------------------- Yedekleme

  @override
  Future<List<BackupProgram>> exportPrograms() => _inner.exportPrograms();

  @override
  Future<int> importPrograms(List<BackupProgram> programs) async {
    final added = await _inner.importPrograms(programs);
    _programChanged();
    return added;
  }
}
