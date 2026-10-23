import 'dart:io';

import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/sqlite_measurement_repository.dart';
import 'package:exercise_tracking_app/data/repositories/sqlite_program_repository.dart';
import 'package:exercise_tracking_app/data/repositories/sqlite_workout_repository.dart';
import 'package:exercise_tracking_app/data/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Gerçek bir dosya üzerinde şema geçişi testleri (bellek içi veritabanı kapanınca kaybolur).
void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exercise_tracking_migration_');
    path = join(tempDir.path, 'exercise_tracking.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Uygulamanın eski bir sürümündeki veritabanını, o sürümün ifadeleriyle elle kurar ve örnek
  /// veri ekler: bir hareket, bir antrenman (not ve set) ve (v2 ve sonrası) bir ölçüm.
  Future<void> createLegacyDatabase(String databasePath, int version) async {
    final db = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          for (final statement in DatabaseService.schemaV1Statements) {
            await db.execute(statement);
          }
          if (version >= 2) {
            for (final statement in DatabaseService.schemaV2Statements) {
              await db.execute(statement);
            }
            for (final (position, type) in builtinMeasurementTypes.indexed) {
              await db.insert('measurement_types', {
                'name': type.name,
                'unit': type.unit,
                'position': position,
                'builtin_key': type.key,
              });
            }
          }
        },
      ),
    );

    final exerciseId = await db.insert('exercises', {
      'name': 'Bench Press',
      'muscle_group': 'chest',
    });
    final workoutId = await db.insert('workouts', {
      'started_at': DateTime(2026, 10, 15, 18, 0).toIso8601String(),
      'title': 'Upper',
    });
    final workoutExerciseId = await db.insert('workout_exercises', {
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'position': 0,
      'note': 'Yavaş indir',
    });
    await db.insert('exercise_sets', {
      'workout_exercise_id': workoutExerciseId,
      'set_number': 1,
      'weight_kg': 60.0,
      'reps': 10,
    });
    if (version >= 2) {
      await db.insert('body_measurements', {
        'type_id': 1,
        'measured_at': DateTime(2026, 10, 18, 7, 0).toIso8601String(),
        'value': 81.5,
      });
    }
    await db.close();
  }

  Future<void> createVersion1Database(String databasePath) =>
      createLegacyDatabase(databasePath, 1);

  Future<int> userVersion(DatabaseService service) async {
    final db = await service.database;
    final rows = await db.rawQuery('PRAGMA user_version');
    return rows.single['user_version'] as int;
  }

  Future<Set<String>> tableNames(DatabaseService service) async {
    final db = await service.database;
    final rows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    return {for (final row in rows) row['name'] as String};
  }

  Future<Set<String>> columnNames(DatabaseService service, String table) async {
    final db = await service.database;
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return {for (final row in rows) row['name'] as String};
  }

  test('v1 veritabanı sürüm 3 olur, eski satırlar aynen kalır ve yerleşik türler gelir', () async {
    await createVersion1Database(path);

    final service = DatabaseService(factory: databaseFactoryFfi, path: path);
    addTearDown(service.close);

    expect(await userVersion(service), 3);

    // Eski antrenman verisi değişmedi ve hâlâ okunabiliyor.
    final workouts = SqliteWorkoutRepository(service);
    final summaries = await workouts.getWorkoutSummaries();
    expect(summaries, hasLength(1));
    expect(summaries.single.workout.title, 'Upper');
    expect(summaries.single.exerciseCount, 1);
    expect(summaries.single.setCount, 1);

    final detail = await workouts.getWorkoutDetail(summaries.single.workout.id);
    expect(detail, isNotNull);
    expect(detail!.exercises.single.exercise.name, 'Bench Press');
    expect(detail.exercises.single.workoutExercise.note, 'Yavaş indir');
    expect(detail.exercises.single.sets.single.weightKg, 60);
    expect(detail.exercises.single.sets.single.reps, 10);

    // Yerleşik 10 ölçüm türü doğru sırada.
    final measurements = SqliteMeasurementRepository(service);
    final types = await measurements.getMeasurementTypes();
    expect(types.map((t) => t.name).toList(), [
      'Kilo',
      'Boy',
      'Sağ kol',
      'Sol kol',
      'Sağ bacak',
      'Sol bacak',
      'Bel',
      'Göğüs',
      'Kalça',
      'Boyun',
    ]);
    expect(types.map((t) => t.builtinKey).toList(), [
      'weight',
      'height',
      'right_arm',
      'left_arm',
      'right_leg',
      'left_leg',
      'waist',
      'chest',
      'hips',
      'neck',
    ]);

    // Yeni tabloya ölçüm eklenebiliyor.
    final added = await measurements.addMeasurement(
      types.first.id,
      81.5,
      measuredAt: DateTime(2026, 10, 20, 7, 0),
    );
    expect((await measurements.getMeasurements(types.first.id)).single, added);
  });

  test('sürüm 3 veritabanı yeniden açılınca yerleşik türler çoğaltılmaz', () async {
    await createVersion1Database(path);

    final first = DatabaseService(factory: databaseFactoryFfi, path: path);
    await userVersion(first);
    await first.close();

    final second = DatabaseService(factory: databaseFactoryFfi, path: path);
    addTearDown(second.close);

    expect(await userVersion(second), 3);
    final types = await SqliteMeasurementRepository(second).getMeasurementTypes();
    expect(types, hasLength(10));
  });

  test('sıfırdan açılan veritabanı sürüm 3 olur, 10 yerleşik tür ve program tablolarıyla gelir',
      () async {
    final service = DatabaseService(factory: databaseFactoryFfi, path: path);
    addTearDown(service.close);

    expect(await userVersion(service), 3);

    final types = await SqliteMeasurementRepository(service).getMeasurementTypes();
    expect(types, hasLength(10));
    expect(types.map((t) => t.position).toList(), List.generate(10, (i) => i));
    expect(types.every((t) => t.isBuiltin), isTrue);

    final workouts = await SqliteWorkoutRepository(service).getWorkoutSummaries();
    expect(workouts, isEmpty);

    expect(
      await tableNames(service),
      containsAll(['programs', 'program_days', 'program_day_exercises']),
    );
    expect(await columnNames(service, 'workouts'), contains('program_day_id'));
    expect(await columnNames(service, 'workout_exercises'),
        containsAll(['target_sets', 'target_reps', 'target_weight_kg']));
  });

  test('v1 veritabanı tek seferde sürüm 3 olur: program tabloları ve yeni sütunlar eklenir', () async {
    await createVersion1Database(path);

    final service = DatabaseService(factory: databaseFactoryFfi, path: path);
    addTearDown(service.close);

    expect(await userVersion(service), 3);
    expect(
      await tableNames(service),
      containsAll(['measurement_types', 'body_measurements', 'programs', 'program_days']),
    );
    expect(await columnNames(service, 'workouts'), contains('program_day_id'));

    // Yerleşik türler bir kez eklenmiş olmalı (v1 → v2 bloğu tek seferde çalıştı).
    final types = await SqliteMeasurementRepository(service).getMeasurementTypes();
    expect(types, hasLength(10));
  });

  test('v2 veritabanı sürüm 3 olur; eski satırlar aynen kalır, yeni sütunlar NULL, program kurulabilir',
      () async {
    await createLegacyDatabase(path, 2);

    final service = DatabaseService(factory: databaseFactoryFfi, path: path);
    addTearDown(service.close);

    expect(await userVersion(service), 3);

    // Eski antrenman, hareket notu ve setleri aynen okunuyor; yeni sütunlar boş.
    final workouts = SqliteWorkoutRepository(service);
    final summaries = await workouts.getWorkoutSummaries();
    expect(summaries, hasLength(1));
    expect(summaries.single.workout.title, 'Upper');
    expect(summaries.single.workout.programDayId, isNull);

    final detail = await workouts.getWorkoutDetail(summaries.single.workout.id);
    final entry = detail!.exercises.single;
    expect(entry.exercise.name, 'Bench Press');
    expect(entry.workoutExercise.note, 'Yavaş indir');
    expect(entry.workoutExercise.target, isNull);
    expect(entry.sets.single.weightKg, 60);
    expect(entry.sets.single.reps, 10);

    // Eski ölçüm de duruyor.
    final measurements = SqliteMeasurementRepository(service);
    final weightType = (await measurements.getMeasurementTypes()).first;
    final weights = await measurements.getMeasurements(weightType.id);
    expect(weights.single.value, 81.5);

    // Program eklenip bu eski veritabanından antrenman başlatılabiliyor.
    final programs = SqliteProgramRepository(service);
    final program = await programs.createProgram('Yeni program');
    expect(program.isActive, isTrue);
    final day = await programs.addDay(program.id, 'Göğüs', weekday: 1);
    final target = ExerciseTarget(sets: 3, reps: 8, weightKg: 70);
    await programs.addDayExercise(day.id, entry.exercise.id, target);

    final started = await programs.startWorkoutFromDay(
      day.id,
      startedAt: DateTime(2026, 10, 23, 18, 0),
    );
    final startedDetail = await workouts.getWorkoutDetail(started.id);
    expect(startedDetail!.workout.programDayId, day.id);
    expect(startedDetail.exercises.single.workoutExercise.target, target);

    // Eski antrenman değişmedi.
    expect(await workouts.getWorkoutSummaries(), hasLength(2));
    final oldDetail = await workouts.getWorkoutDetail(summaries.single.workout.id);
    expect(oldDetail!.workout.programDayId, isNull);
    expect(oldDetail.exercises.single.workoutExercise.target, isNull);
  });
}
