import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/program_repository.dart';
import 'package:exercise_tracking_app/data/utils/text_normalizer.dart';

import 'fake_workout_repository.dart';

/// Testler için tamamen bellekte çalışan [ProgramRepository].
///
/// Gerçek SQLite uygulamasıyla aynı kuralları izler; bunu ortak sözleşme testleri doğrular
/// (bkz. `test/data/repositories/program_repository_contract.dart`).
/// Hareket bilgisi ve antrenman oluşturma için verilen [FakeWorkoutRepository] kullanılır;
/// iki repository aynı veriyi görür. Silinen id'ler tekrar kullanılmaz (SQLite AUTOINCREMENT gibi).
class FakeProgramRepository implements ProgramRepository {
  FakeProgramRepository(this._workouts) {
    _workouts.addExercisesMergedListener(_moveDayExercises);
  }

  final FakeWorkoutRepository _workouts;

  final Map<int, Program> _programs = {};
  final Map<int, ProgramDay> _days = {};
  final Map<int, ProgramDayExercise> _dayExercises = {};

  int _nextProgramId = 1;
  int _nextDayId = 1;
  int _nextDayExerciseId = 1;

  // ------------------------------------------------------------------- Programlar

  @override
  Future<List<Program>> getPrograms() async {
    final programs = _programs.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(programs);
  }

  @override
  Future<ProgramDetail?> getProgramDetail(int programId) async => _detailOf(programId);

  @override
  Future<ProgramDetail?> getActiveProgramDetail() async {
    for (final program in _programs.values) {
      if (program.isActive) return _detailOf(program.id);
    }
    return null;
  }

  @override
  Future<Program> createProgram(String name) async {
    final cleaned = _requireName(name, 'Program adı boş olamaz');
    final program = Program(
      id: _nextProgramId++,
      name: cleaned,
      isActive: !_programs.values.any((p) => p.isActive),
    );
    _programs[program.id] = program;
    return program;
  }

  @override
  Future<void> renameProgram(int programId, String name) async {
    final cleaned = _requireName(name, 'Program adı boş olamaz');
    final current = _programs[programId];
    if (current == null) return;
    _programs[programId] = Program(id: current.id, name: cleaned, isActive: current.isActive);
  }

  @override
  Future<void> setActiveProgram(int programId) async {
    if (!_programs.containsKey(programId)) return;
    for (final id in _programs.keys.toList()) {
      final program = _programs[id]!;
      _programs[id] = Program(
        id: program.id,
        name: program.name,
        isActive: id == programId,
      );
    }
  }

  @override
  Future<void> deleteProgram(int programId) async {
    if (_programs.remove(programId) == null) return;

    for (final day in _daysOf(programId)) {
      _removeDay(day.id);
    }
  }

  // ------------------------------------------------------------------------ Günler

  @override
  Future<ProgramDay> addDay(int programId, String name, {int? weekday}) async {
    final cleaned = _requireName(name, 'Gün adı boş olamaz');
    _validateWeekday(weekday);
    if (!_programs.containsKey(programId)) {
      throw ArgumentError.value(programId, 'id', 'Program bulunamadı');
    }

    final day = ProgramDay(
      id: _nextDayId++,
      programId: programId,
      name: cleaned,
      position: _daysOf(programId).length,
      weekday: weekday,
    );
    _days[day.id] = day;
    return day;
  }

  @override
  Future<void> updateDay(ProgramDay day) async {
    final cleaned = _requireName(day.name, 'Gün adı boş olamaz');
    _validateWeekday(day.weekday);
    final current = _days[day.id];
    if (current == null) return;

    _days[day.id] = ProgramDay(
      id: current.id,
      programId: current.programId,
      name: cleaned,
      position: current.position,
      weekday: day.weekday,
    );
  }

  @override
  Future<void> deleteDay(int dayId) async {
    final day = _days[dayId];
    if (day == null) return;

    _removeDay(dayId);
    _renumberDays(day.programId);
  }

  @override
  Future<void> reorderDays(int programId, List<int> dayIds) async {
    final currentIds = [for (final day in _daysOf(programId)) day.id];
    _requireSameIds(currentIds, dayIds, 'Gün listesi programın günleriyle eşleşmiyor');
    for (var i = 0; i < dayIds.length; i++) {
      final day = _days[dayIds[i]]!;
      _days[day.id] = ProgramDay(
        id: day.id,
        programId: day.programId,
        name: day.name,
        position: i,
        weekday: day.weekday,
      );
    }
  }

  // ----------------------------------------------------------------- Gün hareketleri

  @override
  Future<ProgramDayExercise> addDayExercise(
    int dayId,
    int exerciseId,
    ExerciseTarget target,
  ) async {
    _validateTarget(target);
    if (!_days.containsKey(dayId)) {
      throw ArgumentError.value(dayId, 'dayId', 'Program günü bulunamadı');
    }
    if (_workouts.exerciseById(exerciseId) == null) {
      throw ArgumentError.value(exerciseId, 'exerciseId', 'Hareket bulunamadı');
    }

    final dayExercise = ProgramDayExercise(
      id: _nextDayExerciseId++,
      programDayId: dayId,
      exerciseId: exerciseId,
      position: _dayExercisesOf(dayId).length,
      target: target,
    );
    _dayExercises[dayExercise.id] = dayExercise;
    return dayExercise;
  }

  @override
  Future<void> updateDayExerciseTarget(int dayExerciseId, ExerciseTarget target) async {
    _validateTarget(target);
    final current = _dayExercises[dayExerciseId];
    if (current == null) return;

    _dayExercises[dayExerciseId] = ProgramDayExercise(
      id: current.id,
      programDayId: current.programDayId,
      exerciseId: current.exerciseId,
      position: current.position,
      target: target,
    );
  }

  @override
  Future<void> removeDayExercise(int dayExerciseId) async {
    final removed = _dayExercises.remove(dayExerciseId);
    if (removed == null) return;

    _renumberDayExercises(removed.programDayId);
  }

  @override
  Future<void> reorderDayExercises(int dayId, List<int> dayExerciseIds) async {
    final currentIds = [for (final de in _dayExercisesOf(dayId)) de.id];
    _requireSameIds(currentIds, dayExerciseIds, 'Hareket listesi günün hareketleriyle eşleşmiyor');
    for (var i = 0; i < dayExerciseIds.length; i++) {
      final current = _dayExercises[dayExerciseIds[i]]!;
      _dayExercises[current.id] = ProgramDayExercise(
        id: current.id,
        programDayId: current.programDayId,
        exerciseId: current.exerciseId,
        position: i,
        target: current.target,
      );
    }
  }

  // ------------------------------------------------------------ Antrenman başlatma

  @override
  Future<Workout> startWorkoutFromDay(int dayId, {DateTime? startedAt}) async {
    final day = _days[dayId];
    if (day == null) {
      throw ArgumentError.value(dayId, 'dayId', 'Program günü bulunamadı');
    }

    return _workouts.createWorkoutFromProgram(
      title: day.name,
      programDayId: dayId,
      startedAt: startedAt ?? DateTime.now(),
      entries: [
        for (final de in _dayExercisesOf(dayId))
          (exerciseId: de.exerciseId, target: de.target),
      ],
    );
  }

  // -------------------------------------------------------------------- Yedekleme

  @override
  Future<List<BackupProgram>> exportPrograms() async {
    final programs = _programs.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return [
      for (final program in programs)
        BackupProgram(
          name: program.name,
          isActive: program.isActive,
          days: [
            for (final day in _daysOf(program.id))
              BackupProgramDay(
                name: day.name,
                weekday: day.weekday,
                exercises: [
                  for (final de in _dayExercisesOf(day.id))
                    BackupProgramExercise(
                      exerciseName: _workouts.exerciseById(de.exerciseId)!.name,
                      muscleGroup: _workouts.exerciseById(de.exerciseId)!.muscleGroup,
                      sets: de.target.sets,
                      reps: de.target.reps,
                      weightKg: de.target.weightKg,
                    ),
                ],
              ),
          ],
        ),
    ];
  }

  @override
  Future<int> importPrograms(List<BackupProgram> programs) async {
    // Yazmadan önce tüm girdi doğrulanır: hata varsa hiçbir değişiklik kalmaz.
    for (final program in programs) {
      _requireName(program.name, 'Program adı boş olamaz');
      for (final day in program.days) {
        _requireName(day.name, 'Gün adı boş olamaz');
        _validateWeekday(day.weekday);
        for (final entry in day.exercises) {
          _requireName(entry.exerciseName, 'Hareket adı boş olamaz');
          _validateTarget(ExerciseTarget(
            sets: entry.sets,
            reps: entry.reps,
            weightKg: entry.weightKg,
          ));
        }
      }
    }

    final takenNames = {
      for (final p in _programs.values) normalizeForSearch(p.name),
    };
    var hasActive = _programs.values.any((p) => p.isActive);

    final catalog = <String, Exercise>{
      for (final e in await _workouts.searchExercises('')) normalizeForSearch(e.name): e,
    };
    Future<Exercise> ensureExercise(String name, MuscleGroup muscleGroup) async {
      final cleaned = name.trim();
      final key = normalizeForSearch(cleaned);
      final existing = catalog[key];
      if (existing != null) return existing;

      final created = await _workouts.createExercise(cleaned, muscleGroup);
      catalog[key] = created;
      return created;
    }

    var added = 0;
    for (final program in programs) {
      final cleanName = program.name.trim();
      if (!takenNames.add(normalizeForSearch(cleanName))) continue;

      final makeActive = program.isActive && !hasActive;
      if (makeActive) hasActive = true;
      final programId = _nextProgramId++;
      _programs[programId] = Program(id: programId, name: cleanName, isActive: makeActive);

      for (final (dayPosition, day) in program.days.indexed) {
        final dayId = _nextDayId++;
        _days[dayId] = ProgramDay(
          id: dayId,
          programId: programId,
          name: day.name.trim(),
          position: dayPosition,
          weekday: day.weekday,
        );
        for (final (entryPosition, entry) in day.exercises.indexed) {
          final exercise = await ensureExercise(entry.exerciseName, entry.muscleGroup);
          final dayExerciseId = _nextDayExerciseId++;
          _dayExercises[dayExerciseId] = ProgramDayExercise(
            id: dayExerciseId,
            programDayId: dayId,
            exerciseId: exercise.id,
            position: entryPosition,
            target: ExerciseTarget(
              sets: entry.sets,
              reps: entry.reps,
              weightKg: entry.weightKg,
            ),
          );
        }
      }
      added++;
    }
    return added;
  }

  // ----------------------------------------------------------------- Yardımcılar

  /// Programın ayrıntılı görünümü; program yoksa `null`.
  ProgramDetail? _detailOf(int programId) {
    final program = _programs[programId];
    if (program == null) return null;

    return ProgramDetail(
      program: program,
      days: [
        for (final day in _daysOf(programId))
          ProgramDayDetail(
            day: day,
            exercises: [
              for (final de in _dayExercisesOf(day.id))
                ProgramDayExerciseDetail(
                  dayExercise: de,
                  exercise: _workouts.exerciseById(de.exerciseId)!,
                ),
            ],
          ),
      ],
    );
  }

  /// Bir programın günleri, [ProgramDay.position] sırasıyla.
  List<ProgramDay> _daysOf(int programId) {
    return _days.values.where((d) => d.programId == programId).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  /// Bir günün hareketleri, [ProgramDayExercise.position] sırasıyla.
  List<ProgramDayExercise> _dayExercisesOf(int dayId) {
    return _dayExercises.values.where((de) => de.programDayId == dayId).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  /// Hareket birleştirmesinde kaynağın gün hareketlerini hedefe taşır (SQLite'taki UPDATE ile aynı).
  void _moveDayExercises(int sourceId, int targetId) {
    for (final de in _dayExercises.values.toList()) {
      if (de.exerciseId != sourceId) continue;
      _dayExercises[de.id] = ProgramDayExercise(
        id: de.id,
        programDayId: de.programDayId,
        exerciseId: targetId,
        position: de.position,
        target: de.target,
      );
    }
  }

  /// Günü ve hareketlerini siler; bağlı antrenmanların gün bağlantısı kalkar (ON DELETE SET NULL).
  void _removeDay(int dayId) {
    _dayExercises.removeWhere((_, de) => de.programDayId == dayId);
    _days.remove(dayId);
    _workouts.detachProgramDay(dayId);
  }

  void _renumberDays(int programId) {
    final days = _daysOf(programId);
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      _days[day.id] = ProgramDay(
        id: day.id,
        programId: day.programId,
        name: day.name,
        position: i,
        weekday: day.weekday,
      );
    }
  }

  void _renumberDayExercises(int dayId) {
    final entries = _dayExercisesOf(dayId);
    for (var i = 0; i < entries.length; i++) {
      final de = entries[i];
      _dayExercises[de.id] = ProgramDayExercise(
        id: de.id,
        programDayId: de.programDayId,
        exerciseId: de.exerciseId,
        position: i,
        target: de.target,
      );
    }
  }

  /// [requested] listesi [current] ile birebir aynı kümeyi (her biri bir kez) içermeli.
  void _requireSameIds(List<int> current, List<int> requested, String message) {
    final unique = requested.toSet();
    final same = requested.length == current.length &&
        unique.length == requested.length &&
        unique.containsAll(current);
    if (!same) throw ArgumentError.value(requested, 'ids', message);
  }

  /// Kırpılmış adı döndürür; boşsa [ArgumentError].
  String _requireName(String name, String message) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError.value(name, 'name', message);
    return cleaned;
  }

  /// Gün 1 (Pazartesi) … 7 (Pazar) ya da `null`.
  void _validateWeekday(int? weekday) {
    if (weekday != null && (weekday < DateTime.monday || weekday > DateTime.sunday)) {
      throw ArgumentError.value(weekday, 'weekday', 'Gün 1 (Pazartesi) ile 7 (Pazar) arasında olmalı');
    }
  }

  /// Set ve tekrar 0'dan büyük; ağırlık (varsa) sonlu ve 0 ya da büyük olmalı.
  void _validateTarget(ExerciseTarget target) {
    if (target.sets <= 0) {
      throw ArgumentError.value(target.sets, 'sets', 'Set sayısı 0\'dan büyük olmalı');
    }
    if (target.reps <= 0) {
      throw ArgumentError.value(target.reps, 'reps', 'Tekrar sayısı 0\'dan büyük olmalı');
    }
    final weight = target.weightKg;
    if (weight != null && (!weight.isFinite || weight < 0)) {
      throw ArgumentError.value(weight, 'weightKg', 'Hedef ağırlık negatif olamaz');
    }
  }
}
