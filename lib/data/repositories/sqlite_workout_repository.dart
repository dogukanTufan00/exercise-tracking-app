import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../utils/text_normalizer.dart';
import 'workout_repository.dart';

/// [WorkoutRepository] arayüzünün SQLite (sqflite) uygulaması.
///
/// Metotların davranışı için bkz. `workout_repository.dart` içindeki yorumlar.
class SqliteWorkoutRepository implements WorkoutRepository {
  SqliteWorkoutRepository(this._databaseService);

  final DatabaseService _databaseService;

  Future<Database> get _db => _databaseService.database;

  // ---------------------------------------------------------------- Antrenmanlar

  @override
  Future<List<WorkoutSummary>> getWorkoutSummaries() async {
    final db = await _db;

    final workoutRows = await db.query(
      'workouts',
      orderBy: 'started_at DESC, id DESC',
    );
    if (workoutRows.isEmpty) return [];

    final countRows = await db.rawQuery('''
      SELECT w.id AS workout_id,
             COUNT(DISTINCT we.id) AS exercise_count,
             COUNT(es.id) AS set_count
      FROM workouts w
      LEFT JOIN workout_exercises we ON we.workout_id = w.id
      LEFT JOIN exercise_sets es ON es.workout_exercise_id = we.id
      GROUP BY w.id
    ''');
    final countsByWorkout = <int, Map<String, Object?>>{
      for (final row in countRows) row['workout_id'] as int: row,
    };

    final groupRows = await db.rawQuery('''
      SELECT we.workout_id AS workout_id, e.muscle_group AS muscle_group
      FROM workout_exercises we
      JOIN exercises e ON e.id = we.exercise_id
      ORDER BY we.workout_id, we.position
    ''');
    final groupsByWorkout = <int, List<MuscleGroup>>{};
    for (final row in groupRows) {
      final groups = groupsByWorkout.putIfAbsent(row['workout_id'] as int, () => []);
      final group = MuscleGroup.fromName(row['muscle_group'] as String);
      if (!groups.contains(group)) groups.add(group);
    }

    return [
      for (final row in workoutRows)
        WorkoutSummary(
          workout: Workout.fromMap(row),
          exerciseCount:
              (countsByWorkout[row['id'] as int]?['exercise_count'] as int?) ?? 0,
          setCount: (countsByWorkout[row['id'] as int]?['set_count'] as int?) ?? 0,
          muscleGroups: groupsByWorkout[row['id'] as int] ?? const [],
        ),
    ];
  }

  @override
  Future<WorkoutDetail?> getWorkoutDetail(int workoutId) async {
    final db = await _db;

    final workoutRows = await db.query(
      'workouts',
      where: 'id = ?',
      whereArgs: [workoutId],
    );
    if (workoutRows.isEmpty) return null;

    final exerciseRows = await db.rawQuery('''
      SELECT we.id, we.workout_id, we.exercise_id, we.position, we.note,
             e.name AS exercise_name, e.muscle_group AS exercise_muscle_group
      FROM workout_exercises we
      JOIN exercises e ON e.id = we.exercise_id
      WHERE we.workout_id = ?
      ORDER BY we.position
    ''', [workoutId]);

    final setRows = await db.rawQuery('''
      SELECT es.id, es.workout_exercise_id, es.set_number, es.weight_kg, es.reps
      FROM exercise_sets es
      JOIN workout_exercises we ON we.id = es.workout_exercise_id
      WHERE we.workout_id = ?
      ORDER BY es.workout_exercise_id, es.set_number
    ''', [workoutId]);
    final setsByWorkoutExercise = <int, List<ExerciseSet>>{};
    for (final row in setRows) {
      final exerciseSet = ExerciseSet.fromMap(row);
      setsByWorkoutExercise
          .putIfAbsent(exerciseSet.workoutExerciseId, () => [])
          .add(exerciseSet);
    }

    return WorkoutDetail(
      workout: Workout.fromMap(workoutRows.single),
      exercises: [
        for (final row in exerciseRows)
          WorkoutExerciseDetail(
            workoutExercise: WorkoutExercise.fromMap(row),
            exercise: Exercise(
              id: row['exercise_id'] as int,
              name: row['exercise_name'] as String,
              muscleGroup: MuscleGroup.fromName(row['exercise_muscle_group'] as String),
            ),
            sets: setsByWorkoutExercise[row['id'] as int] ?? const [],
          ),
      ],
    );
  }

  @override
  Future<Workout> createWorkout({String? title, DateTime? startedAt}) async {
    final db = await _db;
    final time = startedAt ?? DateTime.now();
    final cleanTitle = _cleanText(title);

    final id = await db.insert('workouts', {
      'started_at': time.toIso8601String(),
      'title': cleanTitle,
    });
    return Workout(id: id, startedAt: time, title: cleanTitle);
  }

  @override
  Future<void> updateWorkoutTitle(int workoutId, String? title) async {
    final db = await _db;
    await db.update(
      'workouts',
      {'title': _cleanText(title)},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
  }

  @override
  Future<void> deleteWorkout(int workoutId) async {
    // Hareketler ve setler ON DELETE CASCADE ile birlikte silinir.
    final db = await _db;
    await db.delete('workouts', where: 'id = ?', whereArgs: [workoutId]);
  }

  // ------------------------------------------------------------- Hareket kataloğu

  @override
  Future<List<Exercise>> searchExercises(String query) async {
    final db = await _db;
    // Katalog küçük olduğu için (birkaç yüz hareket) filtreleme ve sıralama Dart'ta yapılır;
    // SQLite'ın LIKE/NOCASE'i Türkçe harfleri ve '%' '_' karakterlerini doğru ele almaz.
    final rows = await db.query('exercises');
    final needle = normalizeForSearch(query);

    final matches = [
      for (final row in rows) Exercise.fromMap(row),
    ].where((exercise) => normalizeForSearch(exercise.name).contains(needle)).toList();
    matches.sort(_compareByName);
    return matches;
  }

  @override
  Future<Exercise> createExercise(String name, MuscleGroup muscleGroup) async {
    final db = await _db;
    final cleanName = _cleanText(name);
    if (cleanName == null) {
      throw ArgumentError.value(name, 'name', 'Hareket adı boş olamaz');
    }
    final key = normalizeForSearch(cleanName);

    return db.transaction<Exercise>((txn) async {
      final existing = await txn.query('exercises', columns: ['name']);
      final isDuplicate = existing.any(
        (row) => normalizeForSearch(row['name'] as String) == key,
      );
      if (isDuplicate) throw DuplicateExerciseException(cleanName);

      final id = await txn.insert('exercises', {
        'name': cleanName,
        'muscle_group': muscleGroup.name,
      });
      return Exercise(id: id, name: cleanName, muscleGroup: muscleGroup);
    });
  }

  @override
  Future<Exercise> updateExercise(
    int id, {
    required String name,
    required MuscleGroup muscleGroup,
  }) async {
    final db = await _db;
    final cleanName = _cleanText(name);
    if (cleanName == null) {
      throw ArgumentError.value(name, 'name', 'Hareket adı boş olamaz');
    }
    final key = normalizeForSearch(cleanName);

    return db.transaction<Exercise>((txn) async {
      await _requireExists(txn, 'exercises', id, 'Hareket bulunamadı');

      // Kendi satırı kontrolün dışında tutulur: kendi adının harf büyüklüğünü değiştirebilir.
      final existing = await txn.query('exercises', columns: ['id', 'name']);
      final isDuplicate = existing.any(
        (row) => row['id'] != id && normalizeForSearch(row['name'] as String) == key,
      );
      if (isDuplicate) throw DuplicateExerciseException(cleanName);

      await txn.update(
        'exercises',
        {'name': cleanName, 'muscle_group': muscleGroup.name},
        where: 'id = ?',
        whereArgs: [id],
      );
      return Exercise(id: id, name: cleanName, muscleGroup: muscleGroup);
    });
  }

  // -------------------------------------------------- Antrenmandaki hareketler

  @override
  Future<WorkoutExercise> addExerciseToWorkout(int workoutId, int exerciseId) async {
    final db = await _db;
    return db.transaction<WorkoutExercise>((txn) async {
      await _requireExists(txn, 'workouts', workoutId, 'Antrenman bulunamadı');
      await _requireExists(txn, 'exercises', exerciseId, 'Hareket bulunamadı');

      final rows = await txn.rawQuery(
        'SELECT COALESCE(MAX(position), -1) + 1 AS next_position '
        'FROM workout_exercises WHERE workout_id = ?',
        [workoutId],
      );
      final position = rows.single['next_position'] as int;

      final id = await txn.insert('workout_exercises', {
        'workout_id': workoutId,
        'exercise_id': exerciseId,
        'position': position,
      });
      return WorkoutExercise(
        id: id,
        workoutId: workoutId,
        exerciseId: exerciseId,
        position: position,
      );
    });
  }

  @override
  Future<void> updateExerciseNote(int workoutExerciseId, String? note) async {
    final db = await _db;
    await db.update(
      'workout_exercises',
      {'note': _cleanText(note)},
      where: 'id = ?',
      whereArgs: [workoutExerciseId],
    );
  }

  @override
  Future<void> removeExerciseFromWorkout(int workoutExerciseId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'workout_exercises',
        columns: ['workout_id'],
        where: 'id = ?',
        whereArgs: [workoutExerciseId],
      );
      if (rows.isEmpty) return;
      final workoutId = rows.single['workout_id'] as int;

      await txn.delete(
        'workout_exercises',
        where: 'id = ?',
        whereArgs: [workoutExerciseId],
      );
      await _renumberExercises(txn, workoutId);
    });
  }

  /// Antrenmandaki hareketleri mevcut sıraya göre 0, 1, 2… olarak yeniden numaralar.
  Future<void> _renumberExercises(DatabaseExecutor executor, int workoutId) async {
    final rows = await executor.query(
      'workout_exercises',
      columns: ['id'],
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'position, id',
    );
    for (var i = 0; i < rows.length; i++) {
      await executor.update(
        'workout_exercises',
        {'position': i},
        where: 'id = ?',
        whereArgs: [rows[i]['id']],
      );
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
    final db = await _db;
    return db.transaction<ExerciseSet>((txn) async {
      await _requireExists(
        txn,
        'workout_exercises',
        workoutExerciseId,
        'Antrenmandaki hareket bulunamadı',
      );

      final rows = await txn.rawQuery(
        'SELECT COALESCE(MAX(set_number), 0) + 1 AS next_number '
        'FROM exercise_sets WHERE workout_exercise_id = ?',
        [workoutExerciseId],
      );
      final setNumber = rows.single['next_number'] as int;

      final id = await txn.insert('exercise_sets', {
        'workout_exercise_id': workoutExerciseId,
        'set_number': setNumber,
        'weight_kg': weightKg,
        'reps': reps,
      });
      return ExerciseSet(
        id: id,
        workoutExerciseId: workoutExerciseId,
        setNumber: setNumber,
        weightKg: weightKg,
        reps: reps,
      );
    });
  }

  @override
  Future<void> updateSet(ExerciseSet set) async {
    _validateSet(set.weightKg, set.reps);
    final db = await _db;
    await db.update(
      'exercise_sets',
      {'weight_kg': set.weightKg, 'reps': set.reps},
      where: 'id = ?',
      whereArgs: [set.id],
    );
  }

  @override
  Future<void> deleteSet(int setId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'exercise_sets',
        columns: ['workout_exercise_id'],
        where: 'id = ?',
        whereArgs: [setId],
      );
      if (rows.isEmpty) return;
      final workoutExerciseId = rows.single['workout_exercise_id'] as int;

      await txn.delete('exercise_sets', where: 'id = ?', whereArgs: [setId]);
      await _renumberSets(txn, workoutExerciseId);
    });
  }

  /// Hareketin kalan setlerini mevcut sıraya göre 1, 2, 3… olarak yeniden numaralar.
  Future<void> _renumberSets(DatabaseExecutor executor, int workoutExerciseId) async {
    final rows = await executor.query(
      'exercise_sets',
      columns: ['id'],
      where: 'workout_exercise_id = ?',
      whereArgs: [workoutExerciseId],
      orderBy: 'set_number, id',
    );
    for (var i = 0; i < rows.length; i++) {
      await executor.update(
        'exercise_sets',
        {'set_number': i + 1},
        where: 'id = ?',
        whereArgs: [rows[i]['id']],
      );
    }
  }

  // ---------------------------------------------------------------- "Geçen sefer"

  @override
  Future<List<ExerciseSet>> getPreviousSets(
    int exerciseId, {
    required int beforeWorkoutId,
  }) async {
    final db = await _db;

    final current = await db.query(
      'workouts',
      columns: ['started_at'],
      where: 'id = ?',
      whereArgs: [beforeWorkoutId],
    );
    if (current.isEmpty) return [];
    final startedAt = current.single['started_at'] as String;

    // ISO 8601 metinleri sözlük sırasında doğru karşılaştırılır.
    final previous = await db.rawQuery('''
      SELECT w.id
      FROM workouts w
      JOIN workout_exercises we ON we.workout_id = w.id
      WHERE we.exercise_id = ? AND w.started_at < ?
      ORDER BY w.started_at DESC
      LIMIT 1
    ''', [exerciseId, startedAt]);
    if (previous.isEmpty) return [];

    final workoutExercises = await db.query(
      'workout_exercises',
      columns: ['id'],
      where: 'workout_id = ? AND exercise_id = ?',
      whereArgs: [previous.single['id'], exerciseId],
      orderBy: 'position',
      limit: 1,
    );
    if (workoutExercises.isEmpty) return [];

    final setRows = await db.query(
      'exercise_sets',
      where: 'workout_exercise_id = ?',
      whereArgs: [workoutExercises.single['id']],
      orderBy: 'set_number',
    );
    return [for (final row in setRows) ExerciseSet.fromMap(row)];
  }

  // ------------------------------------------------------------------- İlerleme

  @override
  Future<List<ExerciseSession>> getExerciseHistory(int exerciseId) async {
    final db = await _db;

    // Tek sorgu: her satır bir set; antrenman bilgisi her satırda tekrar eder.
    final rows = await db.rawQuery('''
      SELECT w.id AS w_id, w.started_at, w.title,
             s.id, s.workout_exercise_id, s.set_number, s.weight_kg, s.reps
      FROM exercise_sets s
      JOIN workout_exercises we ON we.id = s.workout_exercise_id
      JOIN workouts w ON w.id = we.workout_id
      WHERE we.exercise_id = ?
      ORDER BY w.started_at, w.id, we.position, s.set_number
    ''', [exerciseId]);

    final sessions = <ExerciseSession>[];
    Workout? workout;
    var sets = <ExerciseSet>[];
    for (final row in rows) {
      final workoutId = row['w_id'] as int;
      if (workout?.id != workoutId) {
        if (workout != null) {
          sessions.add(ExerciseSession(workout: workout, sets: List.unmodifiable(sets)));
        }
        workout = Workout.fromMap({...row, 'id': workoutId});
        sets = [];
      }
      sets.add(ExerciseSet.fromMap(row));
    }
    if (workout != null) {
      sessions.add(ExerciseSession(workout: workout, sets: List.unmodifiable(sets)));
    }
    return List.unmodifiable(sessions);
  }

  // ------------------------------------------------------------------ Yedekleme

  @override
  Future<BackupData> exportBackup() async {
    final db = await _db;

    // Tek bir okuma anlık görüntüsü için her şey bir transaction içinde okunur.
    return db.transaction<BackupData>((txn) async {
      final exerciseRows = await txn.query('exercises');
      final catalog = [for (final row in exerciseRows) Exercise.fromMap(row)]
        ..sort(_compareByName);

      final workoutRows = await txn.query('workouts');
      final workouts = [for (final row in workoutRows) Workout.fromMap(row)]
        ..sort(_compareWorkoutsOldestFirst);

      // Hareketler katalogla JOIN edilerek tek sorguda gelir (N+1 yok).
      final entryRows = await txn.rawQuery('''
        SELECT we.id, we.workout_id, we.note,
               e.name AS exercise_name, e.muscle_group AS exercise_muscle_group
        FROM workout_exercises we
        JOIN exercises e ON e.id = we.exercise_id
        ORDER BY we.position, we.id
      ''');

      final setRows = await txn.rawQuery('''
        SELECT workout_exercise_id, weight_kg, reps
        FROM exercise_sets
        ORDER BY set_number, id
      ''');
      final setsByEntry = <int, List<BackupSet>>{};
      for (final row in setRows) {
        setsByEntry
            .putIfAbsent(row['workout_exercise_id'] as int, () => [])
            .add(BackupSet(
              weightKg: (row['weight_kg'] as num).toDouble(),
              reps: row['reps'] as int,
            ));
      }

      final entriesByWorkout = <int, List<BackupWorkoutExercise>>{};
      for (final row in entryRows) {
        final id = row['id'] as int;
        entriesByWorkout
            .putIfAbsent(row['workout_id'] as int, () => [])
            .add(BackupWorkoutExercise(
              exerciseName: row['exercise_name'] as String,
              muscleGroup: MuscleGroup.fromName(row['exercise_muscle_group'] as String),
              note: row['note'] as String?,
              sets: setsByEntry[id] ?? const [],
            ));
      }

      return BackupData(
        exportedAt: DateTime.now(),
        exercises: [
          for (final exercise in catalog)
            BackupExercise(name: exercise.name, muscleGroup: exercise.muscleGroup),
        ],
        workouts: [
          for (final workout in workouts)
            BackupWorkout(
              startedAt: workout.startedAt,
              title: workout.title,
              exercises: entriesByWorkout[workout.id] ?? const [],
            ),
        ],
      );
    });
  }

  @override
  Future<ImportResult> importBackup(BackupData data) async {
    // Yazmadan önce tüm yedek doğrulanır: hata varsa veritabanına hiçbir şey yazılmaz.
    _validateBackup(data);
    final db = await _db;

    return db.transaction<ImportResult>((txn) async {
      final catalog = <String, Exercise>{};
      for (final row in await txn.query('exercises')) {
        final exercise = Exercise.fromMap(row);
        catalog[normalizeForSearch(exercise.name)] = exercise;
      }

      var addedExercises = 0;
      // Katalogda yoksa oluşturur; varsa mevcut hareketi döndürür.
      Future<Exercise> ensureExercise(String name, MuscleGroup muscleGroup) async {
        final cleaned = name.trim();
        final key = normalizeForSearch(cleaned);
        final existing = catalog[key];
        if (existing != null) return existing;

        final id = await txn.insert('exercises', {
          'name': cleaned,
          'muscle_group': muscleGroup.name,
        });
        addedExercises++;
        final created = Exercise(id: id, name: cleaned, muscleGroup: muscleGroup);
        catalog[key] = created;
        return created;
      }

      for (final exercise in data.exercises) {
        await ensureExercise(exercise.name, exercise.muscleGroup);
      }
      for (final workout in data.workouts) {
        for (final entry in workout.exercises) {
          await ensureExercise(entry.exerciseName, entry.muscleGroup);
        }
      }

      // Başlangıç zamanları metin olarak saklandığı için aynı biçimde karşılaştırılır.
      final takenStarts = {
        for (final row in await txn.query('workouts', columns: ['started_at']))
          row['started_at'] as String,
      };

      var addedWorkouts = 0;
      var skippedWorkouts = 0;
      for (final workout in data.workouts) {
        final startedAt = workout.startedAt.toIso8601String();
        if (!takenStarts.add(startedAt)) {
          skippedWorkouts++;
          continue;
        }

        final workoutId = await txn.insert('workouts', {
          'started_at': startedAt,
          'title': _cleanText(workout.title),
        });
        for (var position = 0; position < workout.exercises.length; position++) {
          final entry = workout.exercises[position];
          final exercise = catalog[normalizeForSearch(entry.exerciseName)]!;
          final workoutExerciseId = await txn.insert('workout_exercises', {
            'workout_id': workoutId,
            'exercise_id': exercise.id,
            'position': position,
            'note': _cleanText(entry.note),
          });
          for (var i = 0; i < entry.sets.length; i++) {
            await txn.insert('exercise_sets', {
              'workout_exercise_id': workoutExerciseId,
              'set_number': i + 1,
              'weight_kg': entry.sets[i].weightKg,
              'reps': entry.sets[i].reps,
            });
          }
        }
        addedWorkouts++;
      }

      return ImportResult(
        addedWorkouts: addedWorkouts,
        skippedWorkouts: skippedWorkouts,
        addedExercises: addedExercises,
      );
    });
  }

  // ---------------------------------------------------------------------- Yardımcılar

  /// Kaydın var olduğunu doğrular; yoksa [ArgumentError] fırlatır.
  Future<void> _requireExists(
    DatabaseExecutor executor,
    String table,
    int id,
    String message,
  ) async {
    final rows = await executor.query(table, columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw ArgumentError.value(id, 'id', message);
  }

  /// Hareketleri normalleştirilmiş ada, eşitlikte orijinal ada göre karşılaştırır.
  static int _compareByName(Exercise a, Exercise b) {
    final byKey = normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name));
    return byKey != 0 ? byKey : a.name.compareTo(b.name);
  }

  /// Kırpılmış metni döndürür; boşsa `null`.
  String? _cleanText(String? text) {
    final trimmed = text?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Antrenmanları en eskiden en yeniye, eşitlikte id sırasıyla karşılaştırır.
  static int _compareWorkoutsOldestFirst(Workout a, Workout b) {
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
}
