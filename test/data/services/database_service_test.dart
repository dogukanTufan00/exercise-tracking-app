import 'dart:io';

import 'package:exercise_tracking_app/data/repositories/sqlite_measurement_repository.dart';
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

  /// Uygulamanın ilk sürümündeki (v1) veritabanını, o sürümün ifadeleriyle elle kurar.
  Future<void> createVersion1Database(String databasePath) async {
    final db = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          for (final statement in DatabaseService.schemaV1Statements) {
            await db.execute(statement);
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
    await db.close();
  }

  Future<int> userVersion(DatabaseService service) async {
    final db = await service.database;
    final rows = await db.rawQuery('PRAGMA user_version');
    return rows.single['user_version'] as int;
  }

  test('v1 veritabanı sürüm 2 olur, eski satırlar aynen kalır ve yerleşik türler gelir', () async {
    await createVersion1Database(path);

    final service = DatabaseService(factory: databaseFactoryFfi, path: path);
    addTearDown(service.close);

    expect(await userVersion(service), 2);

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

  test('sürüm 2 veritabanı yeniden açılınca yerleşik türler çoğaltılmaz', () async {
    await createVersion1Database(path);

    final first = DatabaseService(factory: databaseFactoryFfi, path: path);
    await userVersion(first);
    await first.close();

    final second = DatabaseService(factory: databaseFactoryFfi, path: path);
    addTearDown(second.close);

    expect(await userVersion(second), 2);
    final types = await SqliteMeasurementRepository(second).getMeasurementTypes();
    expect(types, hasLength(10));
  });

  test('sıfırdan açılan veritabanı da sürüm 2 ve 10 yerleşik türle gelir', () async {
    final service = DatabaseService(factory: databaseFactoryFfi, path: path);
    addTearDown(service.close);

    expect(await userVersion(service), 2);

    final types = await SqliteMeasurementRepository(service).getMeasurementTypes();
    expect(types, hasLength(10));
    expect(types.map((t) => t.position).toList(), List.generate(10, (i) => i));
    expect(types.every((t) => t.isBuiltin), isTrue);

    final workouts = await SqliteWorkoutRepository(service).getWorkoutSummaries();
    expect(workouts, isEmpty);
  });
}
