import 'dart:convert';

import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/watch/watch_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_wear_channel.dart';
import '../../fakes/fake_watch_sync_store.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  late DateTime now;
  late FakeWorkoutRepository repo;
  late FakeWearChannel channel;
  late FakeWatchSyncStore store;
  late WatchSyncService service;
  late int workoutId;
  late int workoutExerciseId;

  WatchSyncService makeService() => WatchSyncService(
        repository: repo,
        channel: channel,
        store: store,
        fallbackTitle: (_) => 'Tarih',
        clock: () => now,
      );

  setUp(() async {
    now = DateTime(2026, 11, 21, 19);
    repo = FakeWorkoutRepository();
    channel = FakeWearChannel();
    final exercise = await repo.createExercise('Bench Press', MuscleGroup.chest);
    final workout = await repo.createWorkout(startedAt: DateTime(2026, 11, 21, 18, 30));
    workoutId = workout.id;
    workoutExerciseId = (await repo.addExerciseToWorkout(workoutId, exercise.id)).id;
    store = FakeWatchSyncStore(activeWorkoutId: workoutId);
    service = makeService();
  });

  tearDown(() async {
    await service.dispose();
    await channel.close();
  });

  // ------------------------------------------------------------ Yardımcılar

  String addEvent(
    String eventId, {
    int? workout,
    int? exercise,
    double weightKg = 40,
    int reps = 10,
    int protocol = 1,
  }) {
    return jsonEncode({
      'protocol': protocol,
      'eventId': eventId,
      'type': 'addSet',
      'workoutId': workout ?? workoutId,
      'workoutExerciseId': exercise ?? workoutExerciseId,
      'weightKg': weightKg,
      'reps': reps,
      'createdAt': '2026-11-21T18:41:05.000',
    });
  }

  String deleteEvent(String eventId, int setId, {int? workout}) {
    return jsonEncode({
      'protocol': 1,
      'eventId': eventId,
      'type': 'deleteSet',
      'workoutId': workout ?? workoutId,
      'setId': setId,
      'createdAt': '2026-11-21T18:42:00.000',
    });
  }

  Future<List<ExerciseSet>> setsOf(int workoutIdValue) async {
    final detail = await repo.getWorkoutDetail(workoutIdValue);
    return [for (final e in detail!.exercises) ...e.sets];
  }

  /// Son yayınlanan anlık durumdaki `appliedEventIds`.
  List<String> lastApplied() {
    final snapshot = channel.lastSnapshot!;
    return [for (final id in snapshot['appliedEventIds'] as List<Object?>) id as String];
  }

  // ------------------------------------------------------------ Set ekleme ve silme

  test('addSet olayı seti ekler, onaylar ve anlık durumu yayınlar', () async {
    channel.enqueue(addEvent('e1'));

    await service.processPendingEvents();

    final sets = await setsOf(workoutId);
    expect(sets, hasLength(1));
    expect(sets.single.weightKg, 40);
    expect(sets.single.reps, 10);
    expect(channel.ackedIds, ['e1']);
    expect(channel.pendingEvents, isEmpty);
    expect(lastApplied(), ['e1']);
  });

  test('deleteSet olayı seti siler', () async {
    final set = await repo.addSet(workoutExerciseId, weightKg: 30, reps: 8);
    channel.enqueue(deleteEvent('d1', set.id));

    await service.processPendingEvents();

    expect(await setsOf(workoutId), isEmpty);
    expect(channel.ackedIds, ['d1']);
  });

  test('aynı olay iki kez gelirse set bir kez eklenir', () async {
    channel.enqueue(addEvent('dup'));
    channel.enqueue(addEvent('dup'));
    await service.processPendingEvents();

    expect(await setsOf(workoutId), hasLength(1));

    channel.enqueue(addEvent('dup'));
    await service.processPendingEvents();

    expect(await setsOf(workoutId), hasLength(1));
    expect(channel.ackedIds, contains('dup'));
    expect(channel.pendingEvents, isEmpty);
  });

  // ------------------------------------------------------------ Yok sayılan olaylar

  test('başka antrenman, olmayan hareket, geçersiz değer ve eski protokol uygulanmaz ama ack\'lenir', () async {
    channel.enqueue(addEvent('other', workout: workoutId + 99));
    channel.enqueue(addEvent('noEx', exercise: 9999));
    channel.enqueue(addEvent('negKg', weightKg: -1));
    channel.enqueue(addEvent('zeroReps', reps: 0));
    channel.enqueue(addEvent('oldProto', protocol: 2));

    await service.processPendingEvents();

    expect(await setsOf(workoutId), isEmpty);
    expect(channel.ackedIds, ['other', 'noEx', 'negKg', 'zeroReps', 'oldProto']);
    expect(channel.pendingEvents, isEmpty);
    expect(lastApplied(), ['other', 'noEx', 'negKg', 'zeroReps', 'oldProto']);
  });

  test('olmayan seti silme olayı uygulanmaz ama ack\'lenir', () async {
    channel.enqueue(deleteEvent('ghost', 777777));

    await service.processPendingEvents();

    expect(channel.ackedIds, ['ghost']);
  });

  test('bozuk JSON: eventId metni varsa onaylanır, yoksa kuyrukta kalır', () async {
    channel.enqueue('{"protocol":1,"eventId":"bad-1","type":"addSet"');
    channel.enqueue('bu hiç json değil');

    await service.processPendingEvents();

    expect(channel.ackedIds, ['bad-1']);
    expect(channel.pendingEvents, ['bu hiç json değil']);
    expect(await setsOf(workoutId), isEmpty);
  });

  test('bilinmeyen olay türü onaylanır ve uygulanmaz', () async {
    channel.enqueue(jsonEncode({
      'protocol': 1,
      'eventId': 'weird',
      'type': 'explode',
      'workoutId': workoutId,
      'createdAt': '2026-11-21T18:41:05.000',
    }));

    await service.processPendingEvents();

    expect(channel.ackedIds, ['weird']);
    expect(await setsOf(workoutId), isEmpty);
  });

  // ------------------------------------------------------------ Etkin antrenman

  test('12 saatten eski antrenman etkinliği temizler ve anlık durumu siler', () async {
    final old = await repo.createWorkout(startedAt: now.subtract(const Duration(hours: 13)));
    await repo.addExerciseToWorkout(old.id, (await repo.searchExercises('Bench Press')).single.id);

    await service.setActiveWorkout(old.id);

    expect(channel.snapshots, isEmpty);
    expect(channel.clearCount, greaterThanOrEqualTo(1));
    expect(await store.getActiveWorkoutId(), isNull);
  });

  test('12 saatten yeni antrenman yayınlanır', () async {
    await service.setActiveWorkout(workoutId);

    expect(channel.snapshots, hasLength(1));
    expect(channel.lastSnapshot!['workoutId'], workoutId);
  });

  test('silinmiş etkin antrenman temizlenir', () async {
    await repo.deleteWorkout(workoutId);

    await service.setActiveWorkout(workoutId);

    expect(channel.snapshots, isEmpty);
    expect(await store.getActiveWorkoutId(), isNull);
  });

  test('etkin olmayan antrenmanda workoutChanged yayınlamaz', () async {
    store = FakeWatchSyncStore(activeWorkoutId: null);
    service = makeService();

    await service.workoutChanged(workoutId);

    expect(channel.snapshots, isEmpty);
  });

  test('etkin antrenmanda workoutChanged yeniden yayınlar', () async {
    await service.workoutChanged(workoutId);

    expect(channel.snapshots, hasLength(1));
  });

  test('start etkin antrenmanı yeniden yayınlar', () async {
    await service.start();

    expect(channel.lastSnapshot!['workoutId'], workoutId);
  });

  // ------------------------------------------------------------ Sınırlar

  test('appliedEventIds en fazla 50 olur (son 50)', () async {
    store = FakeWatchSyncStore(
      activeWorkoutId: workoutId,
      processedEventIds: [for (var i = 0; i < 60; i++) 'old$i'],
    );
    service = makeService();

    await service.setActiveWorkout(workoutId);

    final applied = lastApplied();
    expect(applied, hasLength(50));
    expect(applied.first, 'old10');
    expect(applied.last, 'old59');
  });

  test('işlenmiş olay listesi en fazla 200 tutulur', () async {
    store = FakeWatchSyncStore(
      activeWorkoutId: workoutId,
      processedEventIds: [for (var i = 0; i < 200; i++) 'p$i'],
    );
    service = makeService();
    channel.enqueue(addEvent('newest'));

    await service.processPendingEvents();

    final processed = store.processedEventIds;
    expect(processed, hasLength(200));
    expect(processed.first, 'p1');
    expect(processed.last, 'newest');
  });

  // ------------------------------------------------------------ Yayın ve tetikleme

  test('workoutUpdates değişen antrenman id\'sini yayar', () async {
    final emitted = <int>[];
    final sub = service.workoutUpdates.listen(emitted.add);

    channel.enqueue(addEvent('e1'));
    channel.enqueue(addEvent('ignored', workout: workoutId + 99));
    await service.processPendingEvents();
    // Yayın akışı olayları asenkron teslim eder.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();

    expect(emitted, [workoutId]);
  });

  test('eventsAvailable tetiklenince olaylar işlenir', () async {
    await service.start();

    channel.enqueue(addEvent('auto'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await setsOf(workoutId), hasLength(1));
    expect(channel.ackedIds, ['auto']);
  });

  test('eşzamanlı iki processPendingEvents çağrısı seti bir kez ekler', () async {
    channel.enqueue(addEvent('race'));

    await Future.wait([
      service.processPendingEvents(),
      service.processPendingEvents(),
    ]);

    expect(await setsOf(workoutId), hasLength(1));
  });
}
