import 'dart:convert';

import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/rest/rest_controller.dart';
import 'package:exercise_tracking_app/data/watch/watch_sync_service.dart';
import 'package:exercise_tracking_app/domain/rest_timer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_rest_notifier.dart';
import '../../fakes/fake_rest_store.dart';
import '../../fakes/fake_settings_repository.dart';
import '../../fakes/fake_wear_channel.dart';
import '../../fakes/fake_watch_sync_store.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  late DateTime now;
  late FakeWorkoutRepository repo;
  late FakeWearChannel channel;
  late FakeWatchSyncStore syncStore;
  late FakeRestStore restStore;
  late FakeSettingsRepository settings;
  late FakeRestNotifier notifier;
  late WatchSyncService watch;
  late RestController controller;
  late int workoutId;
  late int workoutExerciseId;

  setUp(() async {
    now = DateTime(2026, 11, 24, 19);
    repo = FakeWorkoutRepository();
    channel = FakeWearChannel();
    syncStore = FakeWatchSyncStore();
    restStore = FakeRestStore();
    settings = FakeSettingsRepository();
    notifier = FakeRestNotifier();
    final exercise = await repo.createExercise('Squat', MuscleGroup.legs);
    final workout = await repo.createWorkout(startedAt: DateTime(2026, 11, 24, 18, 30));
    workoutId = workout.id;
    workoutExerciseId = (await repo.addExerciseToWorkout(workoutId, exercise.id)).id;
    syncStore.activeWorkoutId = workoutId;
    watch = WatchSyncService(
      repository: repo,
      programRepository: FakeProgramRepository(repo),
      channel: channel,
      store: syncStore,
      fallbackTitle: (_) => 'Tarih',
      restStore: restStore,
      settings: settings,
      clock: () => now,
    );
    controller = RestController(
      store: restStore,
      settings: settings,
      notifier: notifier,
      watchSync: watch,
      clock: () => now,
    );
  });

  tearDown(() async {
    controller.dispose();
    await watch.dispose();
    await channel.close();
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  /// Gerçek zamanlı zamanlayıcının (80 ms) çalışmasını yavaş makinelerde de bekler.
  Future<void> waitUntil(bool Function() condition) async {
    for (var i = 0; i < 500 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('start sayacı kaydeder, geri sayımı gösterir ve saate yayınlar', () async {
    await controller.start(workoutId);

    final rest = restStore.rest!;
    expect(rest.restId, startsWith('phone-'));
    expect(rest.workoutId, workoutId);
    expect(rest.totalSeconds, restDefaultSeconds);
    expect(rest.endsAt, now.add(const Duration(seconds: restDefaultSeconds)));
    expect(controller.rest, rest);
    expect(notifier.countdowns.single.title, 'Dinlenme');
    expect(notifier.countdowns.single.totalSeconds, restDefaultSeconds);
    final snapshotRest = channel.lastSnapshot!['rest'] as Map<String, Object?>;
    expect(snapshotRest['restId'], rest.restId);
  });

  test('bildirim izni oturum başına bir kez istenir', () async {
    await controller.start(workoutId);
    await controller.start(workoutId);

    expect(notifier.permissionRequests, 1);
  });

  test('skip sayacı titreşimsiz kaldırır, bildirimi iptal eder ve saate yayınlar', () async {
    await controller.start(workoutId);

    await controller.skip();

    expect(restStore.rest, isNull);
    expect(controller.rest, isNull);
    expect(notifier.cancelCount, 1);
    expect(notifier.finishedVibrate, isEmpty);
    expect(channel.lastSnapshot!['rest'], isNull);
  });

  test('adjust süreyi ±15 sn değiştirir ve geri sayımı yeniden gösterir', () async {
    await controller.start(workoutId);

    await controller.adjust(15);

    expect(controller.rest!.totalSeconds, restDefaultSeconds + 15);
    expect(notifier.countdowns.last.totalSeconds, restDefaultSeconds + 15);
  });

  test('adjust sonucu bitiyorsa titreşimsiz temizlenir', () async {
    await controller.start(workoutId);

    await controller.adjust(-200);

    expect(restStore.rest, isNull);
    expect(controller.rest, isNull);
    expect(notifier.cancelCount, 1);
    expect(notifier.finishedVibrate, isEmpty);
  });

  test('clearForWorkout yalnızca kendi antrenmanının sayacını temizler', () async {
    await controller.start(workoutId);

    await controller.clearForWorkout(workoutId + 99);
    expect(restStore.rest, isNotNull);

    await controller.clearForWorkout(workoutId);
    expect(restStore.rest, isNull);
  });

  test('setRestSeconds sınırlar, kaydeder ve saate yayınlar', () async {
    await controller.load();

    await controller.setRestSeconds(5);

    expect(controller.restSeconds, 15);
    expect(await settings.getRestSeconds(), 15);
    expect(channel.publishedRestSeconds.last, 15);
  });

  test('süre dolunca titreşim ayarına göre bitiş bildirimi gösterilir', () async {
    final realController = RestController(
      store: restStore,
      settings: settings,
      notifier: notifier,
      clock: DateTime.now,
    );
    addTearDown(realController.dispose);
    restStore.rest = RestState(
      restId: 'short',
      workoutId: workoutId,
      endsAt: DateTime.now().add(const Duration(milliseconds: 80)),
      totalSeconds: 15,
    );
    await settings.setRestVibrateOnPhone(true);

    await realController.load();
    await waitUntil(() => notifier.finishedVibrate.isNotEmpty);

    expect(notifier.finishedVibrate, [true]);
    expect(restStore.rest, isNull);
    expect(realController.rest, isNull);
  });

  test('titreşim kapalıysa bitişte notifyFinished(vibrate: false) çağrılır', () async {
    final realController = RestController(
      store: restStore,
      settings: settings,
      notifier: notifier,
      clock: DateTime.now,
    );
    addTearDown(realController.dispose);
    restStore.rest = RestState(
      restId: 'quiet',
      workoutId: workoutId,
      endsAt: DateTime.now().add(const Duration(milliseconds: 80)),
      totalSeconds: 15,
    );
    await settings.setRestVibrateOnPhone(false);

    await realController.load();
    await waitUntil(() => notifier.finishedVibrate.isNotEmpty);

    expect(notifier.finishedVibrate, [false]);
  });

  test('saatten gelen sayaç restChanges ile yüklenir ve bildirilir', () async {
    await controller.load();

    channel.enqueue(jsonEncode({
      'protocol': 1,
      'eventId': 'watch-1',
      'type': 'addSet',
      'workoutId': workoutId,
      'workoutExerciseId': workoutExerciseId,
      'weightKg': 60,
      'reps': 5,
      'createdAt': '2026-11-24T19:00:00.000',
      'restSeconds': 60,
    }));
    await watch.processPendingEvents();
    await settle();

    expect(controller.rest!.restId, 'watch-1');
    expect(controller.rest!.totalSeconds, 60);
    expect(notifier.countdowns.last.totalSeconds, 60);
  });

  test('ayar değişince saate yayınlanır ve controller yeni değeri okur', () async {
    await controller.load();

    channel.enqueue(jsonEncode({
      'protocol': 1,
      'eventId': 'set-ayar',
      'type': 'setRestSeconds',
      'workoutId': workoutId,
      'createdAt': '2026-11-24T19:00:00.000',
      'seconds': 120,
    }));
    await watch.processPendingEvents();
    await settle();

    expect(controller.restSeconds, 120);
    expect(channel.publishedRestSeconds.last, 120);
  });
}
