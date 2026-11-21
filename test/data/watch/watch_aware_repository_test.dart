import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/watch/watch_aware_program_repository.dart';
import 'package:exercise_tracking_app/data/watch/watch_aware_workout_repository.dart';
import 'package:exercise_tracking_app/data/watch/watch_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_wear_channel.dart';
import '../../fakes/fake_watch_sync_store.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  late FakeWorkoutRepository repo;
  late FakeProgramRepository programs;
  late FakeWearChannel channel;
  late FakeWatchSyncStore store;
  late WatchSyncService service;
  late Exercise bench;
  late Workout active;
  late Workout other;
  late WorkoutExercise activeExercise;

  setUp(() async {
    repo = FakeWorkoutRepository();
    programs = FakeProgramRepository(repo);
    channel = FakeWearChannel();
    bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    active = await repo.createWorkout(startedAt: DateTime(2026, 11, 21, 18, 30));
    other = await repo.createWorkout(startedAt: DateTime(2026, 11, 20, 18, 30));
    activeExercise = await repo.addExerciseToWorkout(active.id, bench.id);
    store = FakeWatchSyncStore(activeWorkoutId: active.id);
    service = WatchSyncService(
      repository: repo,
      programRepository: programs,
      channel: channel,
      store: store,
      fallbackTitle: (_) => 'Tarih',
      clock: () => DateTime(2026, 11, 21, 19),
    );
  });

  tearDown(() async {
    await service.dispose();
    await channel.close();
  });

  WatchAwareWorkoutRepository watchedWorkouts() => WatchAwareWorkoutRepository(repo, service);
  WatchAwareProgramRepository watchedPrograms() => WatchAwareProgramRepository(programs, service);

  group('WatchAwareWorkoutRepository', () {
    test('etkin antrenmanın set eklemesi anlık durumu yeniden yayınlar', () async {
      await watchedWorkouts().addSet(activeExercise.id, weightKg: 40, reps: 10);
      await pumpEventQueue();

      final exercises = channel.lastSnapshot!['exercises'] as List<Object?>;
      final sets = (exercises.single as Map<String, Object?>)['sets'] as List<Object?>;
      expect(sets, hasLength(1));
    });

    test('etkin olmayan antrenmanın başlığı değişince yayın yapılmaz', () async {
      await watchedWorkouts().updateWorkoutTitle(other.id, 'Yeni');
      await pumpEventQueue();

      expect(channel.snapshots, isEmpty);
    });

    test('etkin antrenmanın başlığı değişince yayınlanır', () async {
      await watchedWorkouts().updateWorkoutTitle(active.id, 'Push A');
      await pumpEventQueue();

      expect(channel.lastSnapshot!['title'], 'Push A');
    });

    test('etkin antrenman silinince saat boş duruma geçer', () async {
      await watchedWorkouts().deleteWorkout(active.id);
      await pumpEventQueue();

      expect(store.activeWorkoutId, isNull);
      expect(channel.clearCount, 1);
    });

    test('okuma metotları yayın yapmaz', () async {
      final w = watchedWorkouts();
      await w.getWorkoutSummaries();
      await w.getWorkoutDetail(active.id);
      await w.searchExercises('bench');
      await w.getPreviousSets(bench.id, beforeWorkoutId: active.id);
      await w.getExerciseHistory(bench.id);
      await w.exportBackup();
      await pumpEventQueue();

      expect(channel.snapshots, isEmpty);
      expect(channel.clearCount, 0);
    });

    test('katalogta hareket oluşturmak yayın yapmaz', () async {
      await watchedWorkouts().createExercise('Squat', MuscleGroup.legs);
      await pumpEventQueue();

      expect(channel.snapshots, isEmpty);
    });

    test('hareket güncellemek etkin antrenmanı yeniden yayınlar', () async {
      await watchedWorkouts().updateExercise(bench.id, name: 'Bench', muscleGroup: MuscleGroup.chest);
      await pumpEventQueue();

      expect(channel.snapshots, hasLength(1));
    });

    test('başarısız değiştirici çağrı yayın yapmaz', () async {
      await expectLater(
        watchedWorkouts().addSet(activeExercise.id, weightKg: -1, reps: 10),
        throwsArgumentError,
      );
      await pumpEventQueue();

      expect(channel.snapshots, isEmpty);
    });
  });

  group('WatchAwareProgramRepository', () {
    test('program değiştirici çağrısı etkin programı yayınlar', () async {
      await watchedPrograms().createProgram('PPL');
      await pumpEventQueue();

      expect(channel.programs, hasLength(1));
    });

    test('okuma metotları program yayınlamaz', () async {
      await watchedPrograms().getPrograms();
      await watchedPrograms().getActiveProgramDetail();
      await pumpEventQueue();

      expect(channel.programs, isEmpty);
      expect(channel.clearProgramCount, 0);
    });

    test('etkin programın silinmesi saatteki programı temizler', () async {
      final program = await watchedPrograms().createProgram('PPL');
      await pumpEventQueue();
      await watchedPrograms().deleteProgram(program.id);
      await pumpEventQueue();

      expect(channel.clearProgramCount, 1);
    });
  });
}
