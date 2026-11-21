import 'dart:convert';

import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/watch/watch_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_wear_channel.dart';
import '../../fakes/fake_watch_sync_store.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  late DateTime now;
  late FakeWorkoutRepository repo;
  late FakeProgramRepository programRepo;
  late FakeWearChannel channel;
  late FakeWatchSyncStore store;
  late WatchSyncService service;
  late int workoutId;
  late int workoutExerciseId;

  WatchSyncService makeService() => WatchSyncService(
        repository: repo,
        programRepository: programRepo,
        channel: channel,
        store: store,
        fallbackTitle: (_) => 'Tarih',
        clock: () => now,
      );

  setUp(() async {
    now = DateTime(2026, 11, 21, 19);
    repo = FakeWorkoutRepository();
    programRepo = FakeProgramRepository(repo);
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

  test('publishTheme kanala tema adını yazar', () async {
    await service.publishTheme(AppThemeId.yellowNavy);

    expect(channel.publishedThemes, ['yellowNavy']);
  });

  // ------------------------------------------------------------ Saatten başlatma (§15.8)

  String startEvent(String eventId, {int? programDayId, DateTime? createdAt}) {
    return jsonEncode({
      'protocol': 1,
      'eventId': eventId,
      'type': 'startWorkout',
      'programDayId': programDayId,
      'createdAt': (createdAt ?? now).toIso8601String(),
    });
  }

  /// Etkin bir program kurar: tek günlü ("Push A", pazartesi) ve bir hareketli.
  Future<int> seedProgramDay() async {
    final program = await programRepo.createProgram('PPL');
    final day = await programRepo.addDay(program.id, 'Push A', weekday: 1);
    final bench = (await repo.searchExercises('Bench Press')).single;
    await programRepo.addDayExercise(
      day.id,
      bench.id,
      const ExerciseTarget(sets: 3, reps: 10, weightKg: 40),
    );
    return day.id;
  }

  test('boş başlatma olayı yeni antrenman açar, etkin yapar ve yayınlar', () async {
    store = FakeWatchSyncStore();
    service = makeService();
    final before = (await repo.getWorkoutSummaries()).length;
    channel.enqueue(startEvent('s1'));

    await service.processPendingEvents();

    final summaries = await repo.getWorkoutSummaries();
    expect(summaries, hasLength(before + 1));
    final created = summaries.first.workout;
    expect(created.startedAt, now);
    expect(await store.getActiveWorkoutId(), created.id);
    expect(channel.lastSnapshot!['workoutId'], created.id);
    expect(channel.ackedIds, ['s1']);
  });

  test('günden başlatma olayı o günün antrenmanını açar', () async {
    store = FakeWatchSyncStore();
    service = makeService();
    final dayId = await seedProgramDay();
    channel.enqueue(startEvent('s2', programDayId: dayId));

    await service.processPendingEvents();

    final created = (await repo.getWorkoutSummaries()).first.workout;
    expect(created.programDayId, dayId);
    expect(created.title, 'Push A');
    expect(await store.getActiveWorkoutId(), created.id);
    final detail = await repo.getWorkoutDetail(created.id);
    expect(detail!.exercises, hasLength(1));
    expect(detail.exercises.single.workoutExercise.target?.sets, 3);
  });

  test('silinmiş gün için başlatma yok sayılır ama onaylanır', () async {
    store = FakeWatchSyncStore();
    service = makeService();
    final before = (await repo.getWorkoutSummaries()).length;
    channel.enqueue(startEvent('s3', programDayId: 9999));

    await service.processPendingEvents();

    expect(await repo.getWorkoutSummaries(), hasLength(before));
    expect(await store.getActiveWorkoutId(), isNull);
    expect(channel.ackedIds, ['s3']);
  });

  test('12 saatten eski başlatma olayı yok sayılır', () async {
    store = FakeWatchSyncStore();
    service = makeService();
    final before = (await repo.getWorkoutSummaries()).length;
    channel.enqueue(startEvent('s4', createdAt: now.subtract(const Duration(hours: 13))));

    await service.processPendingEvents();

    expect(await repo.getWorkoutSummaries(), hasLength(before));
    expect(channel.ackedIds, ['s4']);
  });

  test('aynı başlatma olayı iki kez gelirse tek antrenman açılır', () async {
    store = FakeWatchSyncStore();
    service = makeService();
    final before = (await repo.getWorkoutSummaries()).length;
    channel.enqueue(startEvent('twice'));
    channel.enqueue(startEvent('twice'));
    await service.processPendingEvents();

    channel.enqueue(startEvent('twice'));
    await service.processPendingEvents();

    expect(await repo.getWorkoutSummaries(), hasLength(before + 1));
  });

  test('başlatma sonrası gelen set olayı yeni antrenmana eklenir', () async {
    store = FakeWatchSyncStore();
    service = makeService();
    channel.enqueue(startEvent('s5'));
    await service.processPendingEvents();
    final started = (await repo.getWorkoutSummaries()).first.workout;
    final bench = (await repo.searchExercises('Bench Press')).single;
    final we = await repo.addExerciseToWorkout(started.id, bench.id);
    channel.enqueue(addEvent('after-start', workout: started.id, exercise: we.id));

    await service.processPendingEvents();

    expect(await setsOf(started.id), hasLength(1));
  });

  // ------------------------------------------------------------ Saatten bitirme

  String finishEvent(String eventId, {int? workout}) => jsonEncode({
        'protocol': 1,
        'eventId': eventId,
        'type': 'finishWorkout',
        'workoutId': workout ?? workoutId,
        'createdAt': '2026-11-21T19:00:00.000',
      });

  test('bitirme olayı etkinliği kaldırır, anlık durumu siler, kaydı korur', () async {
    await repo.addSet(workoutExerciseId, weightKg: 30, reps: 8);
    channel.enqueue(finishEvent('f1'));

    await service.processPendingEvents();

    expect(await store.getActiveWorkoutId(), isNull);
    expect(channel.clearCount, greaterThanOrEqualTo(1));
    expect(channel.ackedIds, ['f1']);
    expect(await setsOf(workoutId), hasLength(1));
  });

  test('etkin olmayan antrenmanı bitirme olayı yok sayılır ama onaylanır', () async {
    final other = await repo.createWorkout(startedAt: now);
    channel.enqueue(finishEvent('f2', workout: other.id));

    await service.processPendingEvents();

    expect(await store.getActiveWorkoutId(), workoutId);
    expect(channel.ackedIds, ['f2']);
  });

  test('bitirmeden sonra aynı turda gelen set olayı yok sayılır', () async {
    channel.enqueue(addEvent('before'));
    channel.enqueue(finishEvent('f3'));
    channel.enqueue(addEvent('after'));

    await service.processPendingEvents();

    expect(await setsOf(workoutId), hasLength(1));
    expect(channel.ackedIds, ['before', 'f3', 'after']);
  });

  test('başlatılan antrenman workoutUpdates ile duyurulur', () async {
    store = FakeWatchSyncStore();
    service = makeService();
    final emitted = <int>[];
    final sub = service.workoutUpdates.listen(emitted.add);

    channel.enqueue(startEvent('s6'));
    await service.processPendingEvents();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();

    expect(emitted, [(await repo.getWorkoutSummaries()).first.workout.id]);
  });

  // ------------------------------------------------------------ Program ve işlenen olaylar

  test('programChanged etkin programı yayınlar', () async {
    await seedProgramDay();

    await service.programChanged();

    final json = jsonDecode(channel.programs.single) as Map<String, Object?>;
    expect(json['name'], 'PPL');
    final days = json['days'] as List<Object?>;
    expect(days, hasLength(1));
    final day = days.single as Map<String, Object?>;
    expect(day['name'], 'Push A');
    expect(day['weekday'], 1);
    expect(day['exercises'], ['Bench Press']);
  });

  test('etkin program yoksa programChanged programı siler', () async {
    await service.programChanged();

    expect(channel.programs, isEmpty);
    expect(channel.clearProgramCount, 1);
  });

  test('olay işlenince appliedEventIds yayınlanır', () async {
    channel.enqueue(addEvent('p1'));

    await service.processPendingEvents();

    final payload = jsonDecode(channel.appliedPayloads.last) as Map<String, Object?>;
    expect(payload['protocol'], 1);
    expect(payload['appliedEventIds'], ['p1']);
  });

  test('yok sayılan olay da appliedEventIds içinde yayınlanır', () async {
    channel.enqueue(addEvent('ignored', workout: workoutId + 99));

    await service.processPendingEvents();

    final payload = jsonDecode(channel.appliedPayloads.last) as Map<String, Object?>;
    expect(payload['appliedEventIds'], ['ignored']);
  });

  test('start programı ve işlenen olayları da yayınlar', () async {
    store = FakeWatchSyncStore(processedEventIds: ['old']);
    service = makeService();

    await service.start();

    expect(channel.clearProgramCount, 1);
    final payload = jsonDecode(channel.appliedPayloads.last) as Map<String, Object?>;
    expect(payload['appliedEventIds'], ['old']);
  });
}
