import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/data/utils/text_normalizer.dart';

/// Testler için tamamen bellekte çalışan [WorkoutRepository].
///
/// Gerçek SQLite uygulamasıyla aynı kuralları izler; bunu ortak sözleşme testleri doğrular
/// (bkz. `test/data/repositories/workout_repository_contract.dart`).
/// Silinen id'ler tekrar kullanılmaz (SQLite AUTOINCREMENT gibi).
class FakeWorkoutRepository implements WorkoutRepository {
  final Map<int, Workout> _workouts = {};
  final Map<int, Exercise> _exercises = {};
  final Map<int, WorkoutExercise> _workoutExercises = {};
  final Map<int, ExerciseSet> _sets = {};

  int _nextWorkoutId = 1;
  int _nextExerciseId = 1;
  int _nextWorkoutExerciseId = 1;
  int _nextSetId = 1;

  // ---------------------------------------------------------------- Antrenmanlar

  @override
  Future<List<WorkoutSummary>> getWorkoutSummaries() async {
    final workouts = _workouts.values.toList()..sort(_newestFirst);
    return List.unmodifiable([for (final w in workouts) _summaryOf(w)]);
  }

  @override
  Future<WorkoutDetail?> getWorkoutDetail(int workoutId) async {
    final workout = _workouts[workoutId];
    if (workout == null) return null;

    return WorkoutDetail(
      workout: workout,
      exercises: List.unmodifiable([
        for (final we in _entriesOf(workoutId))
          WorkoutExerciseDetail(
            workoutExercise: we,
            exercise: _exercises[we.exerciseId]!,
            sets: _setsOf(we.id),
          ),
      ]),
    );
  }

  @override
  Future<Workout> createWorkout({String? title, DateTime? startedAt}) async {
    final workout = Workout(
      id: _nextWorkoutId++,
      startedAt: startedAt ?? DateTime.now(),
      title: _cleanText(title),
    );
    _workouts[workout.id] = workout;
    return workout;
  }

  @override
  Future<void> updateWorkoutTitle(int workoutId, String? title) async {
    final workout = _workouts[workoutId];
    if (workout == null) return;
    _workouts[workoutId] = workout.copyWith(title: _cleanText(title));
  }

  @override
  Future<void> deleteWorkout(int workoutId) async {
    if (_workouts.remove(workoutId) == null) return;

    for (final we in _entriesOf(workoutId)) {
      _removeSetsOf(we.id);
      _workoutExercises.remove(we.id);
    }
  }

  // ------------------------------------------------------------- Hareket kataloğu

  @override
  Future<List<Exercise>> searchExercises(String query) async {
    final needle = normalizeForSearch(query);
    final found = _exercises.values
        .where((e) => normalizeForSearch(e.name).contains(needle))
        .toList()
      ..sort(_byNormalizedName);
    return List.unmodifiable(found);
  }

  @override
  Future<Exercise> createExercise(String name, MuscleGroup muscleGroup) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Hareket adı boş olamaz');
    }

    final key = normalizeForSearch(cleaned);
    if (_exercises.values.any((e) => normalizeForSearch(e.name) == key)) {
      throw DuplicateExerciseException(cleaned);
    }

    final exercise = Exercise(
      id: _nextExerciseId++,
      name: cleaned,
      muscleGroup: muscleGroup,
    );
    _exercises[exercise.id] = exercise;
    return exercise;
  }

  // -------------------------------------------------- Antrenmandaki hareketler

  @override
  Future<WorkoutExercise> addExerciseToWorkout(
    int workoutId,
    int exerciseId,
  ) async {
    _requireWorkout(workoutId);
    _requireExercise(exerciseId);

    // Pozisyonlar her zaman 0..n-1 aralığında tutulduğu için sonraki sıra eleman sayısıdır.
    final we = WorkoutExercise(
      id: _nextWorkoutExerciseId++,
      workoutId: workoutId,
      exerciseId: exerciseId,
      position: _entriesOf(workoutId).length,
    );
    _workoutExercises[we.id] = we;
    return we;
  }

  @override
  Future<void> updateExerciseNote(int workoutExerciseId, String? note) async {
    final we = _workoutExercises[workoutExerciseId];
    if (we == null) return;
    _workoutExercises[workoutExerciseId] = we.copyWith(note: _cleanText(note));
  }

  @override
  Future<void> removeExerciseFromWorkout(int workoutExerciseId) async {
    final we = _workoutExercises.remove(workoutExerciseId);
    if (we == null) return;

    _removeSetsOf(workoutExerciseId);
    final remaining = _entriesOf(we.workoutId);
    for (var i = 0; i < remaining.length; i++) {
      _workoutExercises[remaining[i].id] = remaining[i].copyWith(position: i);
    }
  }

  // ----------------------------------------------------------------------- Setler

  @override
  Future<ExerciseSet> addSet(
    int workoutExerciseId, {
    required double weightKg,
    required int reps,
  }) async {
    _validateSet(weightKg, reps);
    _requireWorkoutExercise(workoutExerciseId);

    final existing = _setsOf(workoutExerciseId);
    final set = ExerciseSet(
      id: _nextSetId++,
      workoutExerciseId: workoutExerciseId,
      setNumber: existing.isEmpty ? 1 : existing.last.setNumber + 1,
      weightKg: weightKg,
      reps: reps,
    );
    _sets[set.id] = set;
    return set;
  }

  @override
  Future<void> updateSet(ExerciseSet set) async {
    _validateSet(set.weightKg, set.reps);
    final current = _sets[set.id];
    if (current == null) return;
    _sets[set.id] = current.copyWith(weightKg: set.weightKg, reps: set.reps);
  }

  @override
  Future<void> deleteSet(int setId) async {
    final removed = _sets.remove(setId);
    if (removed == null) return;

    final remaining = _setsOf(removed.workoutExerciseId);
    for (var i = 0; i < remaining.length; i++) {
      _sets[remaining[i].id] = remaining[i].copyWith(setNumber: i + 1);
    }
  }

  // ---------------------------------------------------------------- "Geçen sefer"

  @override
  Future<List<ExerciseSet>> getPreviousSets(
    int exerciseId, {
    required int beforeWorkoutId,
  }) async {
    final reference = _workouts[beforeWorkoutId];
    if (reference == null) return const <ExerciseSet>[];

    // Kesinlikle önce başlamış antrenmanlar, en yenisi önce.
    final candidates = _workouts.values
        .where((w) => w.startedAt.isBefore(reference.startedAt))
        .toList()
      ..sort(_newestFirst);

    for (final workout in candidates) {
      // _entriesOf position sırasıyla döner; ilk eşleşen en küçük position'dır.
      final match = _entriesOf(workout.id)
          .where((we) => we.exerciseId == exerciseId)
          .toList();
      if (match.isNotEmpty) return _setsOf(match.first.id);
    }
    return const <ExerciseSet>[];
  }

  // ------------------------------------------------------------------- İlerleme

  @override
  Future<List<ExerciseSession>> getExerciseHistory(int exerciseId) async {
    final workouts = _workouts.values.toList()..sort(_oldestFirst);
    final sessions = <ExerciseSession>[];
    for (final workout in workouts) {
      final sets = [
        for (final we in _entriesOf(workout.id))
          if (we.exerciseId == exerciseId) ..._setsOf(we.id),
      ];
      if (sets.isNotEmpty) {
        sessions.add(ExerciseSession(workout: workout, sets: List.unmodifiable(sets)));
      }
    }
    return List.unmodifiable(sessions);
  }

  // ------------------------------------------------------------------ Yedekleme

  @override
  Future<BackupData> exportBackup() async {
    final exercises = _exercises.values.toList()..sort(_byNormalizedName);
    final workouts = _workouts.values.toList()..sort(_oldestFirst);

    return BackupData(
      exportedAt: DateTime.now(),
      exercises: [
        for (final e in exercises) BackupExercise(name: e.name, muscleGroup: e.muscleGroup),
      ],
      workouts: [
        for (final workout in workouts)
          BackupWorkout(
            startedAt: workout.startedAt,
            title: workout.title,
            exercises: [
              for (final we in _entriesOf(workout.id))
                BackupWorkoutExercise(
                  exerciseName: _exercises[we.exerciseId]!.name,
                  muscleGroup: _exercises[we.exerciseId]!.muscleGroup,
                  note: we.note,
                  sets: [
                    for (final s in _setsOf(we.id)) BackupSet(weightKg: s.weightKg, reps: s.reps),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  @override
  Future<ImportResult> importBackup(BackupData data) async {
    // Yazmadan önce tüm yedek doğrulanır.
    _validateBackup(data);

    // Değişiklikler önce yerel kopyalarda hesaplanır, en sonda uygulanır.
    var nextExerciseId = _nextExerciseId;
    var nextWorkoutId = _nextWorkoutId;
    var nextWorkoutExerciseId = _nextWorkoutExerciseId;
    var nextSetId = _nextSetId;

    final catalog = <String, Exercise>{
      for (final e in _exercises.values) normalizeForSearch(e.name): e,
    };
    final newExercises = <Exercise>[];
    Exercise ensureExercise(String name, MuscleGroup muscleGroup) {
      final cleaned = name.trim();
      final key = normalizeForSearch(cleaned);
      final existing = catalog[key];
      if (existing != null) return existing;

      final exercise = Exercise(id: nextExerciseId++, name: cleaned, muscleGroup: muscleGroup);
      catalog[key] = exercise;
      newExercises.add(exercise);
      return exercise;
    }

    for (final exercise in data.exercises) {
      ensureExercise(exercise.name, exercise.muscleGroup);
    }
    for (final workout in data.workouts) {
      for (final entry in workout.exercises) {
        ensureExercise(entry.exerciseName, entry.muscleGroup);
      }
    }

    final takenStarts = {for (final w in _workouts.values) w.startedAt};
    final newWorkouts = <Workout>[];
    final newEntries = <WorkoutExercise>[];
    final newSets = <ExerciseSet>[];
    var skippedWorkouts = 0;

    for (final bw in data.workouts) {
      if (!takenStarts.add(bw.startedAt)) {
        skippedWorkouts++;
        continue;
      }

      final workout = Workout(
        id: nextWorkoutId++,
        startedAt: bw.startedAt,
        title: _cleanText(bw.title),
      );
      newWorkouts.add(workout);

      for (var position = 0; position < bw.exercises.length; position++) {
        final entry = bw.exercises[position];
        final exercise = catalog[normalizeForSearch(entry.exerciseName)]!;
        final we = WorkoutExercise(
          id: nextWorkoutExerciseId++,
          workoutId: workout.id,
          exerciseId: exercise.id,
          position: position,
          note: _cleanText(entry.note),
        );
        newEntries.add(we);

        for (var i = 0; i < entry.sets.length; i++) {
          newSets.add(ExerciseSet(
            id: nextSetId++,
            workoutExerciseId: we.id,
            setNumber: i + 1,
            weightKg: entry.sets[i].weightKg,
            reps: entry.sets[i].reps,
          ));
        }
      }
    }

    // Uygulama aşaması: artık hata fırlatmaz.
    _nextExerciseId = nextExerciseId;
    _nextWorkoutId = nextWorkoutId;
    _nextWorkoutExerciseId = nextWorkoutExerciseId;
    _nextSetId = nextSetId;
    for (final e in newExercises) {
      _exercises[e.id] = e;
    }
    for (final w in newWorkouts) {
      _workouts[w.id] = w;
    }
    for (final we in newEntries) {
      _workoutExercises[we.id] = we;
    }
    for (final s in newSets) {
      _sets[s.id] = s;
    }

    return ImportResult(
      addedWorkouts: newWorkouts.length,
      skippedWorkouts: skippedWorkouts,
      addedExercises: newExercises.length,
    );
  }

  // ------------------------------------------------------------------ Yardımcılar

  /// Başlığı / notu kırpar; boşsa `null` döner.
  String? _cleanText(String? text) {
    final trimmed = text?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Hareketler normalleştirilmiş ada göre, eşitlikte orijinal ada göre sıralanır.
  static int _byNormalizedName(Exercise a, Exercise b) {
    final byKey = normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name));
    return byKey != 0 ? byKey : a.name.compareTo(b.name);
  }

  /// Yeniden eskiye; aynı zamanda iki antrenman varsa daha yeni id önce.
  static int _newestFirst(Workout a, Workout b) {
    final byDate = b.startedAt.compareTo(a.startedAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }

  /// Bir antrenmanın hareketleri, [WorkoutExercise.position] sırasıyla.
  List<WorkoutExercise> _entriesOf(int workoutId) {
    return _workoutExercises.values
        .where((we) => we.workoutId == workoutId)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  /// Bir hareketin setleri, [ExerciseSet.setNumber] sırasıyla.
  List<ExerciseSet> _setsOf(int workoutExerciseId) {
    final sets = _sets.values
        .where((s) => s.workoutExerciseId == workoutExerciseId)
        .toList()
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    return List.unmodifiable(sets);
  }

  void _removeSetsOf(int workoutExerciseId) {
    _sets.removeWhere((_, s) => s.workoutExerciseId == workoutExerciseId);
  }

  WorkoutSummary _summaryOf(Workout workout) {
    final entries = _entriesOf(workout.id);
    var setCount = 0;
    final groups = <MuscleGroup>[];
    for (final we in entries) {
      setCount += _setsOf(we.id).length;
      final group = _exercises[we.exerciseId]!.muscleGroup;
      if (!groups.contains(group)) groups.add(group);
    }
    return WorkoutSummary(
      workout: workout,
      exerciseCount: entries.length,
      setCount: setCount,
      muscleGroups: List.unmodifiable(groups),
    );
  }

  /// En eski önce; eşitlikte id sırasıyla.
  static int _oldestFirst(Workout a, Workout b) {
    final byDate = a.startedAt.compareTo(b.startedAt);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  /// Yedeğin tamamını yazmadan önce doğrular.
  void _validateBackup(BackupData data) {
    for (final exercise in data.exercises) {
      _requireName(exercise.name);
    }
    for (final workout in data.workouts) {
      for (final entry in workout.exercises) {
        _requireName(entry.exerciseName);
        for (final set in entry.sets) {
          _validateSet(set.weightKg, set.reps);
        }
      }
    }
  }

  void _requireName(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Hareket adı boş olamaz');
    }
  }

  void _validateSet(double weightKg, int reps) {
    if (weightKg < 0) {
      throw ArgumentError.value(weightKg, 'weightKg', 'Ağırlık negatif olamaz');
    }
    if (reps <= 0) {
      throw ArgumentError.value(reps, 'reps', 'Tekrar sayısı en az 1 olmalı');
    }
  }

  void _requireWorkout(int workoutId) {
    if (!_workouts.containsKey(workoutId)) {
      throw ArgumentError.value(workoutId, 'workoutId', 'Antrenman bulunamadı');
    }
  }

  void _requireExercise(int exerciseId) {
    if (!_exercises.containsKey(exerciseId)) {
      throw ArgumentError.value(exerciseId, 'exerciseId', 'Hareket bulunamadı');
    }
  }

  void _requireWorkoutExercise(int workoutExerciseId) {
    if (!_workoutExercises.containsKey(workoutExerciseId)) {
      throw ArgumentError.value(
        workoutExerciseId,
        'workoutExerciseId',
        'Antrenmandaki hareket bulunamadı',
      );
    }
  }
}
