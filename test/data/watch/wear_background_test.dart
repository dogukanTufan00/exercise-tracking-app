import 'dart:convert';

import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/watch/watch_sync_service.dart';
import 'package:exercise_tracking_app/data/watch/wear_background.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_rest_store.dart';
import '../../fakes/fake_settings_repository.dart';
import '../../fakes/fake_wear_channel.dart';
import '../../fakes/fake_watch_sync_store.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  late FakeWorkoutRepository repo;
  late FakeWearChannel channel;
  late FakeWatchSyncStore store;
  late WatchSyncService service;
  late int workoutId;
  late int workoutExerciseId;

  setUp(() async {
    repo = FakeWorkoutRepository();
    channel = FakeWearChannel();
    final exercise = await repo.createExercise('Squat', MuscleGroup.legs);
    final workout = await repo.createWorkout(startedAt: DateTime(2026, 11, 22, 18));
    workoutId = workout.id;
    workoutExerciseId = (await repo.addExerciseToWorkout(workoutId, exercise.id)).id;
    store = FakeWatchSyncStore(activeWorkoutId: workoutId);
    service = WatchSyncService(
      repository: repo,
      programRepository: FakeProgramRepository(repo),
      channel: channel,
      store: store,
      fallbackTitle: (_) => 'Tarih',
      restStore: FakeRestStore(),
      settings: FakeSettingsRepository(),
      clock: () => DateTime(2026, 11, 22, 19),
    );
  });

  tearDown(() => channel.close());

  test('kuyruktaki olayları işler, yayınlar ve sonra bitti der', () async {
    channel.enqueue(jsonEncode({
      'protocol': 1,
      'eventId': 'bg1',
      'type': 'addSet',
      'workoutId': workoutId,
      'workoutExerciseId': workoutExerciseId,
      'weightKg': 60.0,
      'reps': 5,
      'createdAt': '2026-11-22T18:40:00.000',
    }));
    var doneCalls = 0;
    var ackedBeforeDone = <String>[];

    await runWearBackground(
      service: service,
      onDone: () async {
        doneCalls++;
        ackedBeforeDone = List.of(channel.ackedIds);
      },
    );

    final detail = await repo.getWorkoutDetail(workoutId);
    expect(detail!.exercises.single.sets, hasLength(1));
    expect(ackedBeforeDone, ['bg1']);
    expect(channel.lastSnapshot, isNotNull);
    expect(doneCalls, 1);
  });

  test('kuyruk boşsa da bitti der', () async {
    var doneCalls = 0;

    await runWearBackground(service: service, onDone: () async => doneCalls++);

    expect(doneCalls, 1);
  });
}
