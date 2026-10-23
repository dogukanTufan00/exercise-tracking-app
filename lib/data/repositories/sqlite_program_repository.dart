import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../utils/text_normalizer.dart';
import 'program_repository.dart';

/// [ProgramRepository] arayüzünün SQLite (sqflite) uygulaması.
///
/// Metotların davranışı için bkz. `program_repository.dart` içindeki yorumlar.
class SqliteProgramRepository implements ProgramRepository {
  SqliteProgramRepository(this._databaseService);

  final DatabaseService _databaseService;

  Future<Database> get _db => _databaseService.database;

  // ------------------------------------------------------------------ Programlar

  @override
  Future<List<Program>> getPrograms() async {
    final db = await _db;
    final rows = await db.query('programs', orderBy: 'created_at, id');
    return [for (final row in rows) Program.fromMap(row)];
  }

  @override
  Future<ProgramDetail?> getProgramDetail(int programId) async {
    final db = await _db;
    return _detailOf(db, programId);
  }

  @override
  Future<ProgramDetail?> getActiveProgramDetail() async {
    final db = await _db;
    final rows = await db.query(
      'programs',
      columns: ['id'],
      where: 'is_active = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _detailOf(db, rows.single['id'] as int);
  }

  @override
  Future<Program> createProgram(String name) async {
    final cleanName = _requireName(name, 'Program adı boş olamaz');
    final db = await _db;

    return db.transaction<Program>((txn) async {
      // Henüz etkin program yoksa yeni program etkin olur.
      final active = await txn.query(
        'programs',
        columns: ['id'],
        where: 'is_active = 1',
        limit: 1,
      );
      final isActive = active.isEmpty;

      final id = await txn.insert('programs', {
        'name': cleanName,
        'is_active': isActive ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      return Program(id: id, name: cleanName, isActive: isActive);
    });
  }

  @override
  Future<void> renameProgram(int programId, String name) async {
    final cleanName = _requireName(name, 'Program adı boş olamaz');
    final db = await _db;
    await db.update(
      'programs',
      {'name': cleanName},
      where: 'id = ?',
      whereArgs: [programId],
    );
  }

  @override
  Future<void> setActiveProgram(int programId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'programs',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [programId],
        limit: 1,
      );
      if (rows.isEmpty) return;

      await txn.update('programs', {'is_active': 0}, where: 'is_active = 1');
      await txn.update(
        'programs',
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [programId],
      );
    });
  }

  @override
  Future<void> deleteProgram(int programId) async {
    // Günler ve hareketleri ON DELETE CASCADE ile silinir; antrenmanların
    // program_day_id bağlantısı ON DELETE SET NULL ile boşalır.
    final db = await _db;
    await db.delete('programs', where: 'id = ?', whereArgs: [programId]);
  }

  // ----------------------------------------------------------------------- Günler

  @override
  Future<ProgramDay> addDay(int programId, String name, {int? weekday}) async {
    final cleanName = _requireName(name, 'Gün adı boş olamaz');
    _validateWeekday(weekday);
    final db = await _db;

    return db.transaction<ProgramDay>((txn) async {
      await _requireExists(txn, 'programs', programId, 'Program bulunamadı');

      final position = await _nextPosition(txn, 'program_days', 'program_id', programId);
      final id = await txn.insert('program_days', {
        'program_id': programId,
        'name': cleanName,
        'weekday': weekday,
        'position': position,
      });
      return ProgramDay(
        id: id,
        programId: programId,
        name: cleanName,
        position: position,
        weekday: weekday,
      );
    });
  }

  @override
  Future<void> updateDay(ProgramDay day) async {
    final cleanName = _requireName(day.name, 'Gün adı boş olamaz');
    _validateWeekday(day.weekday);
    final db = await _db;
    await db.update(
      'program_days',
      {'name': cleanName, 'weekday': day.weekday},
      where: 'id = ?',
      whereArgs: [day.id],
    );
  }

  @override
  Future<void> deleteDay(int dayId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'program_days',
        columns: ['program_id'],
        where: 'id = ?',
        whereArgs: [dayId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final programId = rows.single['program_id'] as int;

      // Günün hareketleri ON DELETE CASCADE ile birlikte silinir.
      await txn.delete('program_days', where: 'id = ?', whereArgs: [dayId]);
      await _renumber(txn, 'program_days', 'program_id', programId);
    });
  }

  @override
  Future<void> reorderDays(int programId, List<int> dayIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      final currentIds = await _idsOf(txn, 'program_days', 'program_id', programId);
      _requireSameIds(currentIds, dayIds, 'Gün listesi programın günleriyle eşleşmiyor');
      for (var i = 0; i < dayIds.length; i++) {
        await txn.update(
          'program_days',
          {'position': i},
          where: 'id = ?',
          whereArgs: [dayIds[i]],
        );
      }
    });
  }

  // ------------------------------------------------------------- Gün hareketleri

  @override
  Future<ProgramDayExercise> addDayExercise(
    int dayId,
    int exerciseId,
    ExerciseTarget target,
  ) async {
    _validateTarget(target);
    final db = await _db;

    return db.transaction<ProgramDayExercise>((txn) async {
      await _requireExists(txn, 'program_days', dayId, 'Program günü bulunamadı');
      await _requireExists(txn, 'exercises', exerciseId, 'Hareket bulunamadı');

      final position =
          await _nextPosition(txn, 'program_day_exercises', 'program_day_id', dayId);
      final id = await txn.insert('program_day_exercises', {
        'program_day_id': dayId,
        'exercise_id': exerciseId,
        'position': position,
        ..._targetColumns(target),
      });
      return ProgramDayExercise(
        id: id,
        programDayId: dayId,
        exerciseId: exerciseId,
        position: position,
        target: target,
      );
    });
  }

  @override
  Future<void> updateDayExerciseTarget(int dayExerciseId, ExerciseTarget target) async {
    _validateTarget(target);
    final db = await _db;
    await db.update(
      'program_day_exercises',
      _targetColumns(target),
      where: 'id = ?',
      whereArgs: [dayExerciseId],
    );
  }

  @override
  Future<void> removeDayExercise(int dayExerciseId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'program_day_exercises',
        columns: ['program_day_id'],
        where: 'id = ?',
        whereArgs: [dayExerciseId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final dayId = rows.single['program_day_id'] as int;

      await txn.delete('program_day_exercises', where: 'id = ?', whereArgs: [dayExerciseId]);
      await _renumber(txn, 'program_day_exercises', 'program_day_id', dayId);
    });
  }

  @override
  Future<void> reorderDayExercises(int dayId, List<int> dayExerciseIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      final currentIds =
          await _idsOf(txn, 'program_day_exercises', 'program_day_id', dayId);
      _requireSameIds(
        currentIds,
        dayExerciseIds,
        'Hareket listesi günün hareketleriyle eşleşmiyor',
      );
      for (var i = 0; i < dayExerciseIds.length; i++) {
        await txn.update(
          'program_day_exercises',
          {'position': i},
          where: 'id = ?',
          whereArgs: [dayExerciseIds[i]],
        );
      }
    });
  }

  // ----------------------------------------------------------- Antrenman başlatma

  @override
  Future<Workout> startWorkoutFromDay(int dayId, {DateTime? startedAt}) async {
    final time = startedAt ?? DateTime.now();
    final db = await _db;

    // Antrenman ve hareketleri tek transaction'da yazılır: ya hep ya hiç.
    return db.transaction<Workout>((txn) async {
      final dayRows = await txn.query(
        'program_days',
        where: 'id = ?',
        whereArgs: [dayId],
        limit: 1,
      );
      if (dayRows.isEmpty) {
        throw ArgumentError.value(dayId, 'dayId', 'Program günü bulunamadı');
      }
      final day = ProgramDay.fromMap(dayRows.single);

      final workoutId = await txn.insert('workouts', {
        'started_at': time.toIso8601String(),
        'title': day.name,
        'program_day_id': dayId,
      });

      // Hedefler antrenmana kopyalanır; program sonradan değişse de antrenman etkilenmez.
      final entryRows = await txn.query(
        'program_day_exercises',
        where: 'program_day_id = ?',
        whereArgs: [dayId],
        orderBy: 'position, id',
      );
      for (final (position, row) in entryRows.indexed) {
        await txn.insert('workout_exercises', {
          'workout_id': workoutId,
          'exercise_id': row['exercise_id'],
          'position': position,
          'note': null,
          'target_sets': row['target_sets'],
          'target_reps': row['target_reps'],
          'target_weight_kg': row['target_weight_kg'],
        });
      }

      return Workout(id: workoutId, startedAt: time, title: day.name, programDayId: dayId);
    });
  }

  // -------------------------------------------------------------------- Yedekleme

  @override
  Future<List<BackupProgram>> exportPrograms() async {
    final db = await _db;

    // Tek bir okuma anlık görüntüsü için her şey bir transaction içinde okunur.
    return db.transaction<List<BackupProgram>>((txn) async {
      final programRows = await txn.query('programs', orderBy: 'created_at, id');
      final dayRows = await txn.query('program_days', orderBy: 'position, id');

      final entryRows = await txn.rawQuery('''
        SELECT pde.program_day_id, pde.target_sets, pde.target_reps, pde.target_weight_kg,
               e.name AS exercise_name, e.muscle_group AS exercise_muscle_group
        FROM program_day_exercises pde
        JOIN exercises e ON e.id = pde.exercise_id
        ORDER BY pde.position, pde.id
      ''');
      final entriesByDay = <int, List<BackupProgramExercise>>{};
      for (final row in entryRows) {
        entriesByDay
            .putIfAbsent(row['program_day_id'] as int, () => [])
            .add(BackupProgramExercise(
              exerciseName: row['exercise_name'] as String,
              muscleGroup: MuscleGroup.fromName(row['exercise_muscle_group'] as String),
              sets: row['target_sets'] as int,
              reps: row['target_reps'] as int,
              weightKg: (row['target_weight_kg'] as num?)?.toDouble(),
            ));
      }

      final daysByProgram = <int, List<BackupProgramDay>>{};
      for (final row in dayRows) {
        daysByProgram
            .putIfAbsent(row['program_id'] as int, () => [])
            .add(BackupProgramDay(
              name: row['name'] as String,
              weekday: row['weekday'] as int?,
              exercises: entriesByDay[row['id'] as int] ?? const [],
            ));
      }

      return [
        for (final row in programRows)
          BackupProgram(
            name: row['name'] as String,
            isActive: (row['is_active'] as int) == 1,
            days: daysByProgram[row['id'] as int] ?? const [],
          ),
      ];
    });
  }

  @override
  Future<int> importPrograms(List<BackupProgram> programs) async {
    // Yazmadan önce tüm girdi doğrulanır: hata varsa veritabanına hiçbir şey yazılmaz.
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

    final db = await _db;
    return db.transaction<int>((txn) async {
      // Mevcut program adları (normalleştirilmiş); aynı adlı program atlanır.
      final takenNames = <String>{
        for (final row in await txn.query('programs', columns: ['name']))
          normalizeForSearch(row['name'] as String),
      };
      var hasActive = (await txn.query(
        'programs',
        columns: ['id'],
        where: 'is_active = 1',
        limit: 1,
      ))
          .isNotEmpty;

      // Hareket kataloğu: normalleştirilmiş ad → hareket. Eksikler oluşturulur.
      final catalog = <String, Exercise>{};
      for (final row in await txn.query('exercises')) {
        final exercise = Exercise.fromMap(row);
        catalog[normalizeForSearch(exercise.name)] = exercise;
      }
      Future<int> ensureExerciseId(String name, MuscleGroup muscleGroup) async {
        final cleanName = name.trim();
        final key = normalizeForSearch(cleanName);
        final existing = catalog[key];
        if (existing != null) return existing.id;

        final id = await txn.insert('exercises', {
          'name': cleanName,
          'muscle_group': muscleGroup.name,
        });
        catalog[key] = Exercise(id: id, name: cleanName, muscleGroup: muscleGroup);
        return id;
      }

      // Aynı anda eklenen programların oluşturulma zamanı aynıdır; sıra id ile korunur.
      final createdAt = DateTime.now().toIso8601String();
      var added = 0;
      for (final program in programs) {
        final cleanName = program.name.trim();
        if (!takenNames.add(normalizeForSearch(cleanName))) continue;

        // Yedekte etkin olan program yalnızca şu an etkin program yoksa etkin olur.
        final makeActive = program.isActive && !hasActive;
        if (makeActive) hasActive = true;

        final programId = await txn.insert('programs', {
          'name': cleanName,
          'is_active': makeActive ? 1 : 0,
          'created_at': createdAt,
        });

        for (final (dayPosition, day) in program.days.indexed) {
          final dayId = await txn.insert('program_days', {
            'program_id': programId,
            'name': day.name.trim(),
            'weekday': day.weekday,
            'position': dayPosition,
          });
          for (final (entryPosition, entry) in day.exercises.indexed) {
            final exerciseId = await ensureExerciseId(entry.exerciseName, entry.muscleGroup);
            await txn.insert('program_day_exercises', {
              'program_day_id': dayId,
              'exercise_id': exerciseId,
              'position': entryPosition,
              'target_sets': entry.sets,
              'target_reps': entry.reps,
              'target_weight_kg': entry.weightKg,
            });
          }
        }
        added++;
      }
      return added;
    });
  }

  // ------------------------------------------------------------------ Yardımcılar

  /// Programın ayrıntılı görünümü; program yoksa `null`.
  Future<ProgramDetail?> _detailOf(DatabaseExecutor executor, int programId) async {
    final programRows = await executor.query(
      'programs',
      where: 'id = ?',
      whereArgs: [programId],
      limit: 1,
    );
    if (programRows.isEmpty) return null;

    final dayRows = await executor.query(
      'program_days',
      where: 'program_id = ?',
      whereArgs: [programId],
      orderBy: 'position, id',
    );

    final entryRows = await executor.rawQuery('''
      SELECT pde.id, pde.program_day_id, pde.exercise_id, pde.position,
             pde.target_sets, pde.target_reps, pde.target_weight_kg,
             e.name AS exercise_name, e.muscle_group AS exercise_muscle_group
      FROM program_day_exercises pde
      JOIN program_days pd ON pd.id = pde.program_day_id
      JOIN exercises e ON e.id = pde.exercise_id
      WHERE pd.program_id = ?
      ORDER BY pde.position, pde.id
    ''', [programId]);
    final entriesByDay = <int, List<ProgramDayExerciseDetail>>{};
    for (final row in entryRows) {
      entriesByDay.putIfAbsent(row['program_day_id'] as int, () => []).add(
            ProgramDayExerciseDetail(
              dayExercise: ProgramDayExercise.fromMap(row),
              exercise: Exercise(
                id: row['exercise_id'] as int,
                name: row['exercise_name'] as String,
                muscleGroup: MuscleGroup.fromName(row['exercise_muscle_group'] as String),
              ),
            ),
          );
    }

    return ProgramDetail(
      program: Program.fromMap(programRows.single),
      days: [
        for (final row in dayRows)
          ProgramDayDetail(
            day: ProgramDay.fromMap(row),
            exercises: entriesByDay[row['id'] as int] ?? const [],
          ),
      ],
    );
  }

  /// Kaydın var olduğunu doğrular; yoksa [ArgumentError] fırlatır.
  Future<void> _requireExists(
    DatabaseExecutor executor,
    String table,
    int id,
    String message,
  ) async {
    final rows = await executor.query(
      table,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw ArgumentError.value(id, 'id', message);
  }

  /// Üst kayda bağlı kardeşlerin sonrasındaki konum (MAX(position) + 1; yoksa 0).
  Future<int> _nextPosition(
    DatabaseExecutor executor,
    String table,
    String parentColumn,
    int parentId,
  ) async {
    final rows = await executor.rawQuery(
      'SELECT COALESCE(MAX(position), -1) + 1 AS next_position '
      'FROM $table WHERE $parentColumn = ?',
      [parentId],
    );
    return rows.single['next_position'] as int;
  }

  /// Kardeş kayıtları mevcut sıraya göre 0, 1, 2… olarak yeniden numaralar.
  Future<void> _renumber(
    DatabaseExecutor executor,
    String table,
    String parentColumn,
    int parentId,
  ) async {
    final ids = await _idsOf(executor, table, parentColumn, parentId);
    for (var i = 0; i < ids.length; i++) {
      await executor.update(
        table,
        {'position': i},
        where: 'id = ?',
        whereArgs: [ids[i]],
      );
    }
  }

  /// Üst kayda bağlı kayıtların id'leri, mevcut sıraya göre.
  Future<List<int>> _idsOf(
    DatabaseExecutor executor,
    String table,
    String parentColumn,
    int parentId,
  ) async {
    final rows = await executor.query(
      table,
      columns: ['id'],
      where: '$parentColumn = ?',
      whereArgs: [parentId],
      orderBy: 'position, id',
    );
    return [for (final row in rows) row['id'] as int];
  }

  /// [requested] listesi [current] ile birebir aynı kümeyi (her biri bir kez) içermeli.
  void _requireSameIds(List<int> current, List<int> requested, String message) {
    final unique = requested.toSet();
    final same = requested.length == current.length &&
        unique.length == requested.length &&
        unique.containsAll(current);
    if (!same) throw ArgumentError.value(requested, 'ids', message);
  }

  /// Hedef kolonları (insert/update için).
  Map<String, Object?> _targetColumns(ExerciseTarget target) {
    return {
      'target_sets': target.sets,
      'target_reps': target.reps,
      'target_weight_kg': target.weightKg,
    };
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
