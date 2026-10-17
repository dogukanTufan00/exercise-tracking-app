// WorkoutRepository'nin her uygulamasının (SQLite, Fake, ileride sunucu) geçmesi
// gereken ortak testler. Bu dosya doğrudan çalışmaz (adı _test.dart ile bitmez);
// her uygulamanın kendi test dosyası [runWorkoutRepositoryContractTests]'i çağırır.
import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// [createRepository] her testten önce çağrılır ve **boş** bir repository döndürmelidir.
/// [disposeRepository] verilirse her testten sonra çağrılır (ör. veritabanını kapatmak için).
void runWorkoutRepositoryContractTests(
  String implementationName,
  Future<WorkoutRepository> Function() createRepository, {
  Future<void> Function(WorkoutRepository repository)? disposeRepository,
}) {
  group('$implementationName WorkoutRepository sözleşmesi', () {
    late WorkoutRepository repo;

    setUp(() async {
      repo = await createRepository();
    });

    tearDown(() async {
      await disposeRepository?.call(repo);
    });

    Future<Exercise> exercise(String name, [MuscleGroup group = MuscleGroup.chest]) {
      return repo.createExercise(name, group);
    }

    group('antrenmanlar', () {
      test('createWorkout başlıksız ve şu anki zamanla oluşturur', () async {
        final before = DateTime.now();
        final workout = await repo.createWorkout();
        final after = DateTime.now();

        expect(workout.title, isNull);
        expect(workout.startedAt.isBefore(before), isFalse);
        expect(workout.startedAt.isAfter(after), isFalse);
      });

      test('createWorkout verilen başlık ve zamanı kullanır, başlığı kırpar', () async {
        final startedAt = DateTime(2026, 10, 17, 18, 30);
        final workout = await repo.createWorkout(title: '  Upper  ', startedAt: startedAt);

        expect(workout.title, 'Upper');
        expect(workout.startedAt, startedAt);
      });

      test('createWorkout boş başlığı null saklar', () async {
        final workout = await repo.createWorkout(title: '   ');
        expect(workout.title, isNull);
      });

      test('getWorkoutDetail olmayan antrenman için null döner', () async {
        expect(await repo.getWorkoutDetail(999), isNull);
      });

      test('getWorkoutDetail hareketleri sıraya, setleri numaraya göre döner', () async {
        final workout = await repo.createWorkout(title: 'Upper');
        final bench = await exercise('Bench Press');
        final row = await exercise('Barbell Row', MuscleGroup.back);
        final weBench = await repo.addExerciseToWorkout(workout.id, bench.id);
        final weRow = await repo.addExerciseToWorkout(workout.id, row.id);
        await repo.addSet(weBench.id, weightKg: 60, reps: 10);
        await repo.addSet(weBench.id, weightKg: 65, reps: 8);
        await repo.addSet(weRow.id, weightKg: 50, reps: 12);

        final detail = (await repo.getWorkoutDetail(workout.id))!;

        expect(detail.workout, workout);
        expect(detail.exercises.map((e) => e.exercise.name), ['Bench Press', 'Barbell Row']);
        expect(detail.exercises[0].sets.map((s) => s.setNumber), [1, 2]);
        expect(detail.exercises[0].sets.map((s) => s.weightKg), [60.0, 65.0]);
        expect(detail.exercises[1].sets.single.reps, 12);
      });

      test('getWorkoutSummaries en yeniden eskiye sıralar ve sayıları hesaplar', () async {
        final older = await repo.createWorkout(startedAt: DateTime(2026, 10, 13));
        final newer = await repo.createWorkout(startedAt: DateTime(2026, 10, 17));
        // id sırası ile zaman sırası farklı olsun diye en eskisi en son oluşturuluyor.
        final oldest = await repo.createWorkout(startedAt: DateTime(2026, 10, 1));

        final bench = await exercise('Bench Press', MuscleGroup.chest);
        final row = await exercise('Barbell Row', MuscleGroup.back);
        final fly = await exercise('Cable Fly', MuscleGroup.chest);
        final we1 = await repo.addExerciseToWorkout(newer.id, bench.id);
        final we2 = await repo.addExerciseToWorkout(newer.id, row.id);
        await repo.addExerciseToWorkout(newer.id, fly.id);
        await repo.addSet(we1.id, weightKg: 60, reps: 10);
        await repo.addSet(we1.id, weightKg: 60, reps: 10);
        await repo.addSet(we2.id, weightKg: 50, reps: 10);

        final summaries = await repo.getWorkoutSummaries();

        expect(summaries.map((s) => s.workout.id), [newer.id, older.id, oldest.id]);
        expect(summaries[0].exerciseCount, 3);
        expect(summaries[0].setCount, 3);
        // Her kas grubu bir kez, ilk görülme sırasıyla.
        expect(summaries[0].muscleGroups, [MuscleGroup.chest, MuscleGroup.back]);
        expect(summaries[1].exerciseCount, 0);
        expect(summaries[1].setCount, 0);
        expect(summaries[1].muscleGroups, isEmpty);
      });

      test('updateWorkoutTitle başlığı değiştirir, kırpar ve boşsa kaldırır', () async {
        final workout = await repo.createWorkout(title: 'Upper');

        await repo.updateWorkoutTitle(workout.id, '  Lower ');
        expect((await repo.getWorkoutDetail(workout.id))!.workout.title, 'Lower');

        await repo.updateWorkoutTitle(workout.id, '');
        expect((await repo.getWorkoutDetail(workout.id))!.workout.title, isNull);

        await repo.updateWorkoutTitle(workout.id, 'Push');
        await repo.updateWorkoutTitle(workout.id, null);
        expect((await repo.getWorkoutDetail(workout.id))!.workout.title, isNull);
      });

      test('deleteWorkout antrenmanı siler ama katalog kalır', () async {
        final workout = await repo.createWorkout();
        final bench = await exercise('Bench Press');
        final we = await repo.addExerciseToWorkout(workout.id, bench.id);
        await repo.addSet(we.id, weightKg: 60, reps: 10);

        await repo.deleteWorkout(workout.id);

        expect(await repo.getWorkoutDetail(workout.id), isNull);
        expect(await repo.getWorkoutSummaries(), isEmpty);
        expect(await repo.searchExercises('bench'), [bench]);
      });

      test('olmayan id ile güncelleme ve silme hata fırlatmaz', () async {
        await repo.updateWorkoutTitle(999, 'x');
        await repo.deleteWorkout(999);
        await repo.updateExerciseNote(999, 'x');
        await repo.removeExerciseFromWorkout(999);
        await repo.deleteSet(999);
        await repo.updateSet(
          const ExerciseSet(id: 999, workoutExerciseId: 999, setNumber: 1, weightKg: 1, reps: 1),
        );
      });
    });

    group('hareket kataloğu', () {
      test('createExercise adı kırpar ve kas grubunu saklar', () async {
        final created = await repo.createExercise('  Squat ', MuscleGroup.legs);

        expect(created.name, 'Squat');
        expect(created.muscleGroup, MuscleGroup.legs);
        expect(await repo.searchExercises('squat'), [created]);
      });

      test('createExercise aynı adı büyük/küçük harf fark etmeksizin reddeder', () async {
        await exercise('Bench Press');

        expect(
          () => repo.createExercise('bench press', MuscleGroup.chest),
          throwsA(isA<DuplicateExerciseException>()),
        );
        expect(
          () => repo.createExercise('  BENCH PRESS ', MuscleGroup.chest),
          throwsA(isA<DuplicateExerciseException>()),
        );
      });

      test('createExercise boş adı reddeder', () async {
        expect(
          () => repo.createExercise('   ', MuscleGroup.chest),
          throwsArgumentError,
        );
      });

      test('searchExercises boş sorguda tümünü A→Z döner (harf büyüklüğü fark etmez)', () async {
        await exercise('Squat', MuscleGroup.legs);
        await exercise('bench press');
        await exercise('Deadlift', MuscleGroup.back);

        final all = await repo.searchExercises('');

        expect(all.map((e) => e.name), ['bench press', 'Deadlift', 'Squat']);
      });

      test('searchExercises adın herhangi bir yerinde, harf büyüklüğüne bakmadan arar', () async {
        await exercise('Bench Press');
        await exercise('Incline Bench');
        await exercise('Squat', MuscleGroup.legs);

        final found = await repo.searchExercises('BEN');

        expect(found.map((e) => e.name), ['Bench Press', 'Incline Bench']);
        expect(await repo.searchExercises('xyz'), isEmpty);
      });

      test('searchExercises Türkçe harfleri sadeleştirerek arar', () async {
        final sinav = await exercise('Şınav');
        final incline = await exercise('İncline Press');
        await exercise('Barfiks', MuscleGroup.back);

        for (final query in ['sinav', 'ŞINAV', 'şın', 'SIN']) {
          expect(await repo.searchExercises(query), [sinav], reason: query);
        }
        for (final query in ['incline', 'INCLINE', 'İnc']) {
          expect(await repo.searchExercises(query), [incline], reason: query);
        }
      });

      test('searchExercises Türkçe harfleri sadeleştirilmiş haliyle sıralar', () async {
        await exercise('Dips');
        await exercise('Çekiş', MuscleGroup.back);
        await exercise('Barfiks', MuscleGroup.back);

        final all = await repo.searchExercises('');

        expect(all.map((e) => e.name), ['Barfiks', 'Çekiş', 'Dips']);
      });

      test('searchExercises % ve _ karakterlerini joker olarak yorumlamaz', () async {
        await exercise('Squat', MuscleGroup.legs);
        final percent = await exercise('Squat %90');

        expect(await repo.searchExercises('%'), [percent]);
        expect(await repo.searchExercises('_'), isEmpty);
      });

      test('createExercise Türkçe harf ve boşluk farkını aynı ad sayar', () async {
        await exercise('Şınav');
        await exercise('Bench Press');

        for (final name in ['şınav', 'SINAV', 'sinav', 'Bench   Press']) {
          await expectLater(
            repo.createExercise(name, MuscleGroup.chest),
            throwsA(isA<DuplicateExerciseException>()),
            reason: name,
          );
        }
      });
    });

    group('antrenmandaki hareketler', () {
      test('addExerciseToWorkout sona ekler: position 0, 1, 2', () async {
        final workout = await repo.createWorkout();
        final a = await exercise('A');
        final b = await exercise('B');
        final c = await exercise('C');

        final weA = await repo.addExerciseToWorkout(workout.id, a.id);
        final weB = await repo.addExerciseToWorkout(workout.id, b.id);
        final weC = await repo.addExerciseToWorkout(workout.id, c.id);

        expect([weA.position, weB.position, weC.position], [0, 1, 2]);
        expect(weA.workoutId, workout.id);
        expect(weA.exerciseId, a.id);
        expect(weA.note, isNull);
      });

      test('updateExerciseNote notu kırpar ve boşsa kaldırır', () async {
        final workout = await repo.createWorkout();
        final bench = await exercise('Bench Press');
        final we = await repo.addExerciseToWorkout(workout.id, bench.id);

        await repo.updateExerciseNote(we.id, ' 2. sette formum bozuldu ');
        var detail = (await repo.getWorkoutDetail(workout.id))!;
        expect(detail.exercises.single.workoutExercise.note, '2. sette formum bozuldu');

        await repo.updateExerciseNote(we.id, '  ');
        detail = (await repo.getWorkoutDetail(workout.id))!;
        expect(detail.exercises.single.workoutExercise.note, isNull);
      });

      test('removeExerciseFromWorkout setleriyle kaldırır ve sırayı yeniden numaralar', () async {
        final workout = await repo.createWorkout();
        final a = await exercise('A');
        final b = await exercise('B');
        final c = await exercise('C');
        await repo.addExerciseToWorkout(workout.id, a.id);
        final weB = await repo.addExerciseToWorkout(workout.id, b.id);
        await repo.addExerciseToWorkout(workout.id, c.id);
        await repo.addSet(weB.id, weightKg: 10, reps: 10);

        await repo.removeExerciseFromWorkout(weB.id);

        final detail = (await repo.getWorkoutDetail(workout.id))!;
        expect(detail.exercises.map((e) => e.exercise.name), ['A', 'C']);
        expect(detail.exercises.map((e) => e.workoutExercise.position), [0, 1]);
        final summary = (await repo.getWorkoutSummaries()).single;
        expect(summary.setCount, 0);
      });

      test('aynı hareket bir antrenmana iki kez eklenebilir', () async {
        final workout = await repo.createWorkout();
        final bench = await exercise('Bench Press');

        await repo.addExerciseToWorkout(workout.id, bench.id);
        await repo.addExerciseToWorkout(workout.id, bench.id);

        final detail = (await repo.getWorkoutDetail(workout.id))!;
        expect(detail.exercises, hasLength(2));
      });

      test('addExerciseToWorkout olmayan antrenman ya da hareket için ArgumentError fırlatır', () async {
        final workout = await repo.createWorkout();
        final bench = await exercise('Bench Press');

        await expectLater(repo.addExerciseToWorkout(999, bench.id), throwsArgumentError);
        await expectLater(repo.addExerciseToWorkout(workout.id, 999), throwsArgumentError);
        expect((await repo.getWorkoutDetail(workout.id))!.exercises, isEmpty);
      });
    });

    group('setler', () {
      late WorkoutExercise we;

      setUp(() async {
        final workout = await repo.createWorkout();
        final bench = await exercise('Bench Press');
        we = await repo.addExerciseToWorkout(workout.id, bench.id);
      });

      Future<List<ExerciseSet>> setsOf(WorkoutExercise target) async {
        final detail = (await repo.getWorkoutDetail(target.workoutId))!;
        return detail.exercises
            .firstWhere((e) => e.workoutExercise.id == target.id)
            .sets;
      }

      test('addSet set numarasını artırır ve değerleri saklar', () async {
        final s1 = await repo.addSet(we.id, weightKg: 60, reps: 10);
        final s2 = await repo.addSet(we.id, weightKg: 62.5, reps: 8);

        expect(s1.setNumber, 1);
        expect(s2.setNumber, 2);
        expect(s2.workoutExerciseId, we.id);
        expect(await setsOf(we), [s1, s2]);
      });

      test('addSet 0 kg kabul eder (vücut ağırlığı), negatif ağırlığı ve 0 tekrarı reddeder', () async {
        final bodyweight = await repo.addSet(we.id, weightKg: 0, reps: 12);
        expect(bodyweight.weightKg, 0);

        expect(() => repo.addSet(we.id, weightKg: -1, reps: 10), throwsArgumentError);
        expect(() => repo.addSet(we.id, weightKg: 60, reps: 0), throwsArgumentError);
      });

      test('addSet olmayan antrenman hareketi için ArgumentError fırlatır', () async {
        await expectLater(repo.addSet(999, weightKg: 60, reps: 10), throwsArgumentError);
      });

      test('updateSet ağırlık ve tekrarı günceller, geçersiz değeri reddeder', () async {
        final set = await repo.addSet(we.id, weightKg: 60, reps: 10);

        await repo.updateSet(set.copyWith(weightKg: 65, reps: 6));
        expect((await setsOf(we)).single, set.copyWith(weightKg: 65, reps: 6));

        expect(() => repo.updateSet(set.copyWith(reps: 0)), throwsArgumentError);
        expect(() => repo.updateSet(set.copyWith(weightKg: -5)), throwsArgumentError);
      });

      test('deleteSet kalan setleri 1, 2, 3 diye yeniden numaralar', () async {
        await repo.addSet(we.id, weightKg: 60, reps: 10);
        final s2 = await repo.addSet(we.id, weightKg: 65, reps: 8);
        await repo.addSet(we.id, weightKg: 70, reps: 6);

        await repo.deleteSet(s2.id);

        final sets = await setsOf(we);
        expect(sets.map((s) => s.setNumber), [1, 2]);
        expect(sets.map((s) => s.weightKg), [60.0, 70.0]);

        final s3 = await repo.addSet(we.id, weightKg: 75, reps: 4);
        expect(s3.setNumber, 3);
      });
    });

    group('geçen sefer', () {
      test('verilen antrenmandan önceki en son antrenmanın setlerini döner', () async {
        final bench = await exercise('Bench Press');
        final squat = await exercise('Squat', MuscleGroup.legs);

        Future<Workout> workoutWith(DateTime at, Exercise ex, List<double> weights) async {
          final w = await repo.createWorkout(startedAt: at);
          final we = await repo.addExerciseToWorkout(w.id, ex.id);
          for (final kg in weights) {
            await repo.addSet(we.id, weightKg: kg, reps: 8);
          }
          return w;
        }

        // Oluşturma sırası zaman sırasından farklı: id'ye değil startedAt'e bakılmalı.
        final current = await workoutWith(DateTime(2026, 10, 17), bench, [70]);
        await workoutWith(DateTime(2026, 10, 1), bench, [50, 55]);
        await workoutWith(DateTime(2026, 10, 10), bench, [60, 62.5]);
        await workoutWith(DateTime(2026, 10, 20), bench, [80]); // sonraki: sayılmaz
        await workoutWith(DateTime(2026, 10, 15), squat, [100]); // başka hareket

        final previous = await repo.getPreviousSets(bench.id, beforeWorkoutId: current.id);

        expect(previous.map((s) => s.weightKg), [60.0, 62.5]);
        expect(previous.map((s) => s.setNumber), [1, 2]);
      });

      test('önceki antrenman yoksa boş liste döner', () async {
        final bench = await exercise('Bench Press');
        final w = await repo.createWorkout();
        await repo.addExerciseToWorkout(w.id, bench.id);

        expect(await repo.getPreviousSets(bench.id, beforeWorkoutId: w.id), isEmpty);
      });
    });

    group('yedekleme', () {
      /// Karşılaştırma için yedeği id'lerden ve exportedAt'ten bağımsız satırlara çevirir.
      List<String> describe(BackupData data) => [
            for (final e in data.exercises) 'katalog: ${e.name} (${e.muscleGroup.name})',
            for (final w in data.workouts) ...[
              'antrenman: ${w.startedAt.toIso8601String()} | ${w.title}',
              for (final we in w.exercises) ...[
                '  hareket: ${we.exerciseName} (${we.muscleGroup.name}) | not: ${we.note}',
                for (final s in we.sets) '    set: ${s.weightKg} x ${s.reps}',
              ],
            ],
          ];

      BackupData backupOf(List<BackupWorkout> workouts, [List<BackupExercise> exercises = const []]) {
        return BackupData(exportedAt: DateTime(2026, 10, 18), exercises: exercises, workouts: workouts);
      }

      BackupWorkout workoutAt(DateTime at, {String? title, List<BackupWorkoutExercise>? exercises}) {
        return BackupWorkout(
          startedAt: at,
          title: title,
          exercises: exercises ??
              const [
                BackupWorkoutExercise(
                  exerciseName: 'Bench Press',
                  muscleGroup: MuscleGroup.chest,
                  sets: [BackupSet(weightKg: 60, reps: 10)],
                ),
              ],
        );
      }

      /// Örnek veriyi repository'nin normal metotlarıyla oluşturur.
      Future<void> seed(WorkoutRepository target) async {
        final bench = await target.createExercise('Bench Press', MuscleGroup.chest);
        final row = await target.createExercise('Barbell Row', MuscleGroup.back);
        await target.createExercise('Şınav', MuscleGroup.chest); // hiç kullanılmıyor

        final newer = await target.createWorkout(title: 'Upper', startedAt: DateTime(2026, 10, 17, 18, 30));
        final older = await target.createWorkout(startedAt: DateTime(2026, 10, 10, 19));

        final weB = await target.addExerciseToWorkout(newer.id, bench.id);
        final weR = await target.addExerciseToWorkout(newer.id, row.id);
        await target.addSet(weB.id, weightKg: 60, reps: 10);
        await target.addSet(weB.id, weightKg: 62.5, reps: 8);
        await target.addSet(weR.id, weightKg: 50, reps: 12);
        await target.updateExerciseNote(weB.id, '2. sette formum bozuldu');

        final weOld = await target.addExerciseToWorkout(older.id, bench.id);
        await target.addSet(weOld.id, weightKg: 55, reps: 10);
      }

      test('boş repository boş yedek verir', () async {
        final backup = await repo.exportBackup();

        expect(backup.formatVersion, BackupData.currentFormatVersion);
        expect(backup.exercises, isEmpty);
        expect(backup.workouts, isEmpty);
      });

      test('exportBackup tüm veriyi sıralı ve eksiksiz verir', () async {
        await seed(repo);

        final backup = await repo.exportBackup();

        expect(describe(backup), [
          'katalog: Barbell Row (back)',
          'katalog: Bench Press (chest)',
          'katalog: Şınav (chest)',
          'antrenman: ${DateTime(2026, 10, 10, 19).toIso8601String()} | null',
          '  hareket: Bench Press (chest) | not: null',
          '    set: 55.0 x 10',
          'antrenman: ${DateTime(2026, 10, 17, 18, 30).toIso8601String()} | Upper',
          '  hareket: Bench Press (chest) | not: 2. sette formum bozuldu',
          '    set: 60.0 x 10',
          '    set: 62.5 x 8',
          '  hareket: Barbell Row (back) | not: null',
          '    set: 50.0 x 12',
        ]);
      });

      test('dışa aktar → boş repository\'ye içe aktar → aynı veri', () async {
        await seed(repo);
        final original = await repo.exportBackup();

        final target = await createRepository();
        final result = await target.importBackup(original);
        final copy = await target.exportBackup();
        await disposeRepository?.call(target);

        expect(result, const ImportResult(addedWorkouts: 2, skippedWorkouts: 0, addedExercises: 3));
        expect(describe(copy), describe(original));
      });

      test('aynı yedeği iki kez içe aktarmak kopya oluşturmaz', () async {
        final backup = backupOf([workoutAt(DateTime(2026, 10, 1)), workoutAt(DateTime(2026, 10, 2))]);

        final first = await repo.importBackup(backup);
        final second = await repo.importBackup(backup);

        expect(first, const ImportResult(addedWorkouts: 2, skippedWorkouts: 0, addedExercises: 1));
        expect(second, const ImportResult(addedWorkouts: 0, skippedWorkouts: 2, addedExercises: 0));
        expect(await repo.getWorkoutSummaries(), hasLength(2));
      });

      test('mevcut verilerle birleştirir; mevcut veriye dokunmaz', () async {
        await seed(repo);
        final before = describe(await repo.exportBackup());

        final result = await repo.importBackup(backupOf([
          workoutAt(DateTime(2026, 10, 17, 18, 30), title: 'Çakışan'), // seed'de var → atlanır
          workoutAt(DateTime(2026, 10, 20), title: 'Yeni'),
        ]));

        expect(result, const ImportResult(addedWorkouts: 1, skippedWorkouts: 1, addedExercises: 0));
        final after = describe(await repo.exportBackup());
        // Yeni antrenman en yenisi olduğu için dışa aktarmanın sonuna eklenir; öncesi aynen kalmalı.
        expect(after.sublist(0, before.length), before);
        expect(after[before.length], 'antrenman: ${DateTime(2026, 10, 20).toIso8601String()} | Yeni');
        expect(after, isNot(contains(contains('Çakışan'))));
      });

      test('hareketleri Türkçe harf duyarsız adla eşleştirir, eksikleri oluşturur', () async {
        final sinav = await repo.createExercise('Şınav', MuscleGroup.chest);

        final result = await repo.importBackup(backupOf([
          workoutAt(DateTime(2026, 10, 1), exercises: const [
            BackupWorkoutExercise(exerciseName: 'SINAV', muscleGroup: MuscleGroup.other, sets: []),
            BackupWorkoutExercise(exerciseName: 'Squat', muscleGroup: MuscleGroup.legs, sets: []),
          ]),
        ], const [
          BackupExercise(name: 'Dips', muscleGroup: MuscleGroup.arms), // kullanılmayan katalog hareketi
        ]));

        expect(result.addedExercises, 2);
        final catalog = await repo.searchExercises('');
        expect(catalog.map((e) => e.name), ['Dips', 'Şınav', 'Squat']);
        expect(catalog.firstWhere((e) => e.name == 'Squat').muscleGroup, MuscleGroup.legs);

        final summary = (await repo.getWorkoutSummaries()).single;
        final detail = (await repo.getWorkoutDetail(summary.workout.id))!;
        expect(detail.exercises.first.exercise, sinav);
      });

      test('yedek içinde aynı zamanlı iki antrenman varsa ikincisi atlanır', () async {
        final at = DateTime(2026, 10, 5, 18);
        final result = await repo.importBackup(backupOf([workoutAt(at, title: 'A'), workoutAt(at, title: 'B')]));

        expect(result.addedWorkouts, 1);
        expect(result.skippedWorkouts, 1);
        expect((await repo.getWorkoutSummaries()).single.workout.title, 'A');
      });

      test('başlık ve notları diğer metotlardaki kurallarla saklar', () async {
        await repo.importBackup(backupOf([
          workoutAt(DateTime(2026, 10, 1), title: '   ', exercises: const [
            BackupWorkoutExercise(
              exerciseName: '  Bench Press ',
              muscleGroup: MuscleGroup.chest,
              note: '  kolay geldi  ',
              sets: [BackupSet(weightKg: 0, reps: 12)],
            ),
          ]),
        ]));

        final summary = (await repo.getWorkoutSummaries()).single;
        final detail = (await repo.getWorkoutDetail(summary.workout.id))!;
        expect(detail.workout.title, isNull);
        expect(detail.exercises.single.exercise.name, 'Bench Press');
        expect(detail.exercises.single.workoutExercise.note, 'kolay geldi');
        expect(detail.exercises.single.sets.single.setNumber, 1);
      });

      test('geçersiz veride ArgumentError fırlatır ve hiçbir şey değiştirmez', () async {
        await seed(repo);
        final before = describe(await repo.exportBackup());

        final invalidBackups = [
          backupOf([
            workoutAt(DateTime(2026, 11, 1)),
            workoutAt(DateTime(2026, 11, 2), exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Squat',
                muscleGroup: MuscleGroup.legs,
                sets: [BackupSet(weightKg: 100, reps: 0)],
              ),
            ]),
          ]),
          backupOf([
            workoutAt(DateTime(2026, 11, 3), exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Squat',
                muscleGroup: MuscleGroup.legs,
                sets: [BackupSet(weightKg: -5, reps: 5)],
              ),
            ]),
          ]),
          backupOf([
            workoutAt(DateTime(2026, 11, 4), exercises: const [
              BackupWorkoutExercise(exerciseName: '   ', muscleGroup: MuscleGroup.legs, sets: []),
            ]),
          ]),
        ];

        for (final backup in invalidBackups) {
          await expectLater(repo.importBackup(backup), throwsArgumentError);
          expect(describe(await repo.exportBackup()), before);
        }
      });
    });
  });
}
