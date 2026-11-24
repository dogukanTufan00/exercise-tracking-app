import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/sqlite_program_repository.dart';
import 'package:exercise_tracking_app/data/repositories/sqlite_workout_repository.dart';
import 'package:exercise_tracking_app/data/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'workout_repository_contract.dart';

void main() {
  sqfliteFfiInit();
  late DatabaseService service;
  runWorkoutRepositoryContractTests(
    'SQLite',
    () async {
      service = DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      return SqliteWorkoutRepository(service);
    },
    disposeRepository: (_) => service.close(),
  );

  group('SQLite ek testleri', () {
    test('iki ayrı DatabaseService birbirinin verisini görmez', () async {
      final serviceA = DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      final serviceB = DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      addTearDown(serviceA.close);
      addTearDown(serviceB.close);

      final repoA = SqliteWorkoutRepository(serviceA);
      final repoB = SqliteWorkoutRepository(serviceB);
      await repoA.createWorkout(title: 'Sadece A');

      expect(await repoA.getWorkoutSummaries(), hasLength(1));
      expect(await repoB.getWorkoutSummaries(), isEmpty);
    });

    test('deleteWorkout yabancı anahtar kurallarıyla ilgili satırları da siler', () async {
      final dbService =
          DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      addTearDown(dbService.close);
      final repo = SqliteWorkoutRepository(dbService);

      final workout = await repo.createWorkout(title: 'Upper');
      final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
      final we = await repo.addExerciseToWorkout(workout.id, bench.id);
      await repo.addSet(we.id, weightKg: 60, reps: 10);
      await repo.addSet(we.id, weightKg: 62.5, reps: 8);

      await repo.deleteWorkout(workout.id);

      final db = await dbService.database;
      final setCount = await db.rawQuery('SELECT COUNT(*) AS c FROM exercise_sets');
      final weCount = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM workout_exercises WHERE workout_id = ?',
        [workout.id],
      );
      expect(setCount.single['c'], 0);
      expect(weCount.single['c'], 0);
      expect(await repo.searchExercises('bench'), [bench]);
    });

    test('mergeExercises program gün hareketini hedefe taşır (ON DELETE RESTRICT aşılır)', () async {
      final dbService =
          DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      addTearDown(dbService.close);
      final repo = SqliteWorkoutRepository(dbService);
      final programs = SqliteProgramRepository(dbService);

      final source = await repo.createExercise('Bench', MuscleGroup.chest);
      final target = await repo.createExercise('Bench Press', MuscleGroup.chest);
      final programId = (await programs.createProgram('Plan')).id;
      final dayId = (await programs.addDay(programId, 'Gün A')).id;
      await programs.addDayExercise(
        dayId,
        source.id,
        const ExerciseTarget(sets: 3, reps: 10, weightKg: 40),
      );

      await repo.mergeExercises(sourceId: source.id, targetId: target.id);

      final detail = (await programs.getProgramDetail(programId))!;
      expect(detail.days.single.exercises.single.exercise.id, target.id);
      expect(detail.days.single.exercises.single.dayExercise.exerciseId, target.id);
      expect(await repo.searchExercises('bench'), [target]);
    });
  });

  group('bitiş anı (şema 4, §16.3)', () {
    test('yazılır, okunur, kaldırılır; olmayan antrenman sessizce geçer', () async {
      final dbService =
          DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      addTearDown(dbService.close);
      final repo = SqliteWorkoutRepository(dbService);

      final workout = await repo.createWorkout(
        title: 'Upper',
        startedAt: DateTime(2026, 11, 24, 18, 0),
      );
      expect(workout.finishedAt, isNull);

      final end = DateTime(2026, 11, 24, 19, 12);
      await repo.setWorkoutFinishedAt(workout.id, end);
      expect((await repo.getWorkoutDetail(workout.id))!.workout.finishedAt, end);

      await repo.setWorkoutFinishedAt(workout.id, null);
      expect((await repo.getWorkoutDetail(workout.id))!.workout.finishedAt, isNull);

      await repo.setWorkoutFinishedAt(999, end);
      expect(await repo.getWorkoutSummaries(), hasLength(1));
    });

    test('bitiş anı özette ve detayda görünür', () async {
      final dbService =
          DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      addTearDown(dbService.close);
      final repo = SqliteWorkoutRepository(dbService);

      final workout = await repo.createWorkout(startedAt: DateTime(2026, 11, 24, 18, 0));
      final end = DateTime(2026, 11, 24, 18, 45);
      await repo.setWorkoutFinishedAt(workout.id, end);

      final summaries = await repo.getWorkoutSummaries();
      expect(summaries.single.workout.finishedAt, end);
      final detail = await repo.getWorkoutDetail(workout.id);
      expect(detail!.workout.finishedAt, end);
    });

    test('dışa aktarma bitiş anını taşır, içe aktarma yazar', () async {
      final sourceService =
          DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      addTearDown(sourceService.close);
      final source = SqliteWorkoutRepository(sourceService);
      final finished = await source.createWorkout(startedAt: DateTime(2026, 11, 20, 18, 0));
      final end = DateTime(2026, 11, 20, 19, 5);
      await source.setWorkoutFinishedAt(finished.id, end);
      await source.createWorkout(startedAt: DateTime(2026, 11, 21, 18, 0));

      final data = await source.exportBackup();
      expect(data.workouts.map((w) => w.finishedAt), [end, null]);

      final targetService =
          DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      addTearDown(targetService.close);
      final target = SqliteWorkoutRepository(targetService);
      await target.importBackup(data);

      final imported = await target.getWorkoutSummaries();
      final byStart = {for (final s in imported) s.workout.startedAt: s.workout};
      expect(byStart[DateTime(2026, 11, 20, 18, 0)]!.finishedAt, end);
      expect(byStart[DateTime(2026, 11, 21, 18, 0)]!.finishedAt, isNull);
    });
  });
}
