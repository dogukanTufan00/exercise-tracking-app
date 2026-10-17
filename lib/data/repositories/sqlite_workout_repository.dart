import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../services/database_service.dart';
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
    final trimmed = query.trim();

    final rows = trimmed.isEmpty
        ? await db.query('exercises', orderBy: 'name COLLATE NOCASE')
        : await db.query(
            'exercises',
            where: 'name LIKE ? COLLATE NOCASE',
            whereArgs: ['%$trimmed%'],
            orderBy: 'name COLLATE NOCASE',
          );
    return [for (final row in rows) Exercise.fromMap(row)];
  }

  @override
  Future<Exercise> createExercise(String name, MuscleGroup muscleGroup) async {
    final db = await _db;
    final cleanName = _cleanText(name);
    if (cleanName == null) {
      throw ArgumentError.value(name, 'name', 'Hareket adı boş olamaz');
    }

    final existing = await db.query(
      'exercises',
      columns: ['id'],
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [cleanName],
      limit: 1,
    );
    if (existing.isNotEmpty) throw DuplicateExerciseException(cleanName);

    final id = await db.insert('exercises', {
      'name': cleanName,
      'muscle_group': muscleGroup.name,
    });
    return Exercise(id: id, name: cleanName, muscleGroup: muscleGroup);
  }

  // -------------------------------------------------- Antrenmandaki hareketler

  @override
  Future<WorkoutExercise> addExerciseToWorkout(int workoutId, int exerciseId) async {
    final db = await _db;
    return db.transaction<WorkoutExercise>((txn) async {
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

  // ---------------------------------------------------------------------- Yardımcılar

  /// Kırpılmış metni döndürür; boşsa `null`.
  String? _cleanText(String? text) {
    final trimmed = text?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
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
