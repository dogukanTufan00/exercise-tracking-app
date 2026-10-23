import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/workout/workout_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../fakes/fake_workout_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  late FakeWorkoutRepository repo;
  late Exercise bench;
  late Exercise squat;

  setUp(() async {
    repo = FakeWorkoutRepository();
    bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    squat = await repo.createExercise('Squat', MuscleGroup.legs);
  });

  /// Antrenmandan önce başlamış bir antrenman oluşturur; bench'e verilen setleri ekler.
  Future<void> createPreviousWithBench(List<(double, int)> sets) async {
    final previous = await repo.createWorkout(
      startedAt: DateTime(2026, 10, 1, 18),
    );
    final we = await repo.addExerciseToWorkout(previous.id, bench.id);
    for (final (kg, reps) in sets) {
      await repo.addSet(we.id, weightKg: kg, reps: reps);
    }
  }

  Future<WorkoutViewModel> loadedVm(int workoutId) async {
    final vm = WorkoutViewModel(repo, workoutId);
    await vm.load();
    return vm;
  }

  group('load ve başlık', () {
    test('detayı yükler ve başlık yoksa tarihi kullanır', () async {
      final workout = await repo.createWorkout(
        startedAt: DateTime(2026, 10, 17, 18, 30),
      );
      final vm = await loadedVm(workout.id);

      expect(vm.detail?.workout.id, workout.id);
      expect(vm.isLoading, isFalse);
      expect(vm.title, '17 Ekim 2026 · 18:30');
      vm.dispose();
    });

    test('başlık varsa başlığı kullanır', () async {
      final workout = await repo.createWorkout(title: 'Upper');
      final vm = await loadedVm(workout.id);

      expect(vm.title, 'Upper');
      vm.dispose();
    });

    test('antrenman yoksa detail null ve title boş', () async {
      final vm = await loadedVm(999);

      expect(vm.detail, isNull);
      expect(vm.title, '');
      vm.dispose();
    });
  });

  group('taslak kuralı', () {
    test('bu antrenmandaki son set değerlerini kullanır', () async {
      await createPreviousWithBench([(40, 8)]);
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, bench.id);
      await repo.addSet(we.id, weightKg: 50, reps: 8);
      await repo.addSet(we.id, weightKg: 60, reps: 10);

      final vm = await loadedVm(workout.id);
      expect(vm.draftFor(we.id).weightKg, 60);
      expect(vm.draftFor(we.id).reps, 10);
      vm.dispose();
    });

    test('bu antrenmanda set yoksa geçen seferin ilk setini kullanır', () async {
      await createPreviousWithBench([(40, 8), (45, 6)]);
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, bench.id);

      final vm = await loadedVm(workout.id);
      expect(vm.draftFor(we.id).weightKg, 40);
      expect(vm.draftFor(we.id).reps, 8);
      vm.dispose();
    });

    test('ikisi de yoksa 20 kg × 10 kullanır', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);

      final vm = await loadedVm(workout.id);
      expect(vm.draftFor(we.id).weightKg, 20);
      expect(vm.draftFor(we.id).reps, 10);
      vm.dispose();
    });

    test('set eklemek taslağı değiştirmez; kullanıcı değiştirince değişir', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);

      await vm.addSet(we.id);
      expect(vm.draftFor(we.id).weightKg, 20);

      vm.setDraftWeight(we.id, 62.5);
      vm.setDraftReps(we.id, 5);
      expect(vm.draftFor(we.id).weightKg, 62.5);
      expect(vm.draftFor(we.id).reps, 5);
      vm.dispose();
    });
  });

  group('setler', () {
    test('addSet taslakla set ekler ve numara artar', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);

      vm.setDraftWeight(we.id, 60);
      await vm.addSet(we.id);
      await vm.addSet(we.id);

      final sets = vm.detail!.exercises.single.sets;
      expect(sets.map((s) => s.setNumber), [1, 2]);
      expect(sets.first.weightKg, 60);
      expect(sets.first.reps, 10);
      vm.dispose();
    });

    test('repeatLastSet son seti kopyalar', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      await repo.addSet(we.id, weightKg: 70, reps: 6);
      final vm = await loadedVm(workout.id);

      await vm.repeatLastSet(we.id);

      final sets = vm.detail!.exercises.single.sets;
      expect(sets.length, 2);
      expect(sets.last.weightKg, 70);
      expect(sets.last.reps, 6);
      expect(sets.last.setNumber, 2);
      vm.dispose();
    });

    test('repeatLastSet set yoksa hiçbir şey yapmaz', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);

      await vm.repeatLastSet(we.id);

      expect(vm.detail!.exercises.single.sets, isEmpty);
      vm.dispose();
    });

    test('deleteSet seti siler ve kalanları yeniden numaralar', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      final first = await repo.addSet(we.id, weightKg: 50, reps: 5);
      await repo.addSet(we.id, weightKg: 55, reps: 5);
      final vm = await loadedVm(workout.id);

      await vm.deleteSet(first.id);

      final sets = vm.detail!.exercises.single.sets;
      expect(sets.length, 1);
      expect(sets.single.setNumber, 1);
      expect(sets.single.weightKg, 55);
      vm.dispose();
    });

    test('updateSet değerleri günceller', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      final set = await repo.addSet(we.id, weightKg: 50, reps: 5);
      final vm = await loadedVm(workout.id);

      await vm.updateSet(set.copyWith(weightKg: 52.5, reps: 6));

      final updated = vm.detail!.exercises.single.sets.single;
      expect(updated.weightKg, 52.5);
      expect(updated.reps, 6);
      vm.dispose();
    });
  });

  group('hareketler', () {
    test('addExercise sonrası previousSetsFor dolu', () async {
      await createPreviousWithBench([(40, 8)]);
      final workout = await repo.createWorkout();
      final vm = await loadedVm(workout.id);

      await vm.addExercise(bench);

      final previous = vm.previousSetsFor(bench.id);
      expect(previous.length, 1);
      expect(previous.single.weightKg, 40);
      expect(vm.detail!.exercises.length, 1);
      vm.dispose();
    });

    test('previousSetsFor bilinmeyen hareket için boş liste döner', () async {
      final workout = await repo.createWorkout();
      final vm = await loadedVm(workout.id);

      expect(vm.previousSetsFor(squat.id), isEmpty);
      vm.dispose();
    });

    test('removeExercise hareketi ve setlerini kaldırır', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      await repo.addSet(we.id, weightKg: 50, reps: 5);
      final vm = await loadedVm(workout.id);

      await vm.removeExercise(we.id);

      expect(vm.detail!.exercises, isEmpty);
      vm.dispose();
    });
  });

  group('notlar', () {
    test('updateNote 500 ms sonra kaydeder', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);

      vm.updateNote(we.id, 'Formum bozuldu');
      final before = await repo.getWorkoutDetail(workout.id);
      expect(before!.exercises.single.workoutExercise.note, isNull);

      await Future<void>.delayed(const Duration(milliseconds: 600));

      final after = await repo.getWorkoutDetail(workout.id);
      expect(after!.exercises.single.workoutExercise.note, 'Formum bozuldu');
      vm.dispose();
    });

    test('flushNotes bekleyen notu hemen kaydeder', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);

      vm.updateNote(we.id, 'Hemen');
      await vm.flushNotes();

      final after = await repo.getWorkoutDetail(workout.id);
      expect(after!.exercises.single.workoutExercise.note, 'Hemen');
      vm.dispose();
    });
  });

  group('discardIfEmpty ve başlık', () {
    test('hareket yoksa antrenmanı siler', () async {
      final workout = await repo.createWorkout();
      final vm = await loadedVm(workout.id);

      await vm.discardIfEmpty();

      expect(await repo.getWorkoutDetail(workout.id), isNull);
      vm.dispose();
    });

    test('hareket varsa antrenmanı silmez', () async {
      final workout = await repo.createWorkout();
      await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);

      await vm.discardIfEmpty();

      expect(await repo.getWorkoutDetail(workout.id), isNotNull);
      vm.dispose();
    });

    test('updateTitle boş metinle başlığı kaldırır', () async {
      final workout = await repo.createWorkout(
        title: 'Upper',
        startedAt: DateTime(2026, 10, 17, 18, 30),
      );
      final vm = await loadedVm(workout.id);

      await vm.updateTitle('');

      expect(vm.detail!.workout.title, isNull);
      expect(vm.title, '17 Ekim 2026 · 18:30');
      vm.dispose();
    });
  });

  group('katlanabilir kartlar', () {
    test('ilk yüklemede yalnızca son hareket açık', () async {
      final workout = await repo.createWorkout();
      final first = await repo.addExerciseToWorkout(workout.id, bench.id);
      final second = await repo.addExerciseToWorkout(workout.id, squat.id);

      final vm = await loadedVm(workout.id);

      expect(vm.isExpanded(first.id), isFalse);
      expect(vm.isExpanded(second.id), isTrue);
      vm.dispose();
    });

    test('toggleExpanded kartı açar, kapatır ve bildirir', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);
      var notifications = 0;
      vm.addListener(() => notifications++);

      expect(vm.isExpanded(we.id), isTrue);
      vm.toggleExpanded(we.id);
      expect(vm.isExpanded(we.id), isFalse);
      vm.toggleExpanded(we.id);
      expect(vm.isExpanded(we.id), isTrue);
      expect(notifications, 2);
      vm.dispose();
    });

    test('set ekleme ve yeniden yükleme açık/kapalı durumunu değiştirmez', () async {
      final workout = await repo.createWorkout();
      final first = await repo.addExerciseToWorkout(workout.id, bench.id);
      final second = await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);

      vm.toggleExpanded(first.id);
      vm.toggleExpanded(second.id);
      await vm.addSet(first.id);
      await vm.load();

      expect(vm.isExpanded(first.id), isTrue);
      expect(vm.isExpanded(second.id), isFalse);
      vm.dispose();
    });

    test('addExercise yeni hareketi açar, diğerlerini değiştirmez', () async {
      final workout = await repo.createWorkout();
      final first = await repo.addExerciseToWorkout(workout.id, bench.id);
      final vm = await loadedVm(workout.id);
      vm.toggleExpanded(first.id);

      await vm.addExercise(squat);

      final newId = vm.detail!.exercises.last.workoutExercise.id;
      expect(vm.isExpanded(newId), isTrue);
      expect(vm.isExpanded(first.id), isFalse);
      vm.dispose();
    });

    test('removeExercise hareketin açık durumunu da siler', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);
      expect(vm.isExpanded(we.id), isTrue);

      await vm.removeExercise(we.id);

      expect(vm.isExpanded(we.id), isFalse);
      vm.dispose();
    });
  });

  group('hareket düzenleme', () {
    test('updateExercise sonrası detail yeni adı ve kas grubunu içerir', () async {
      final workout = await repo.createWorkout();
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);

      final ok = await vm.updateExercise(squat.id, 'Front Squat', MuscleGroup.back);

      expect(ok, isTrue);
      final entry = vm.detail!.exercises.single;
      expect(entry.workoutExercise.id, we.id);
      expect(entry.exercise.name, 'Front Squat');
      expect(entry.exercise.muscleGroup, MuscleGroup.back);
      expect(vm.errorMessage, isNull);
      vm.dispose();
    });

    test('çakışmada errorMessage ayarlanır ve false döner', () async {
      final workout = await repo.createWorkout();
      await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);

      final ok = await vm.updateExercise(bench.id, 'SQUAT', MuscleGroup.chest);

      expect(ok, isFalse);
      expect(vm.errorMessage, 'Bu adda bir hareket zaten var.');
      expect(vm.detail!.exercises.single.exercise.name, 'Squat');
      vm.dispose();
    });
  });

  group('rekorlar', () {
    /// Taslağı verilen değerlere ayarlayıp seti ekler.
    Future<void> addSetWith(WorkoutViewModel vm, int we, double kg, int reps) async {
      vm.setDraftWeight(we, kg);
      vm.setDraftReps(we, reps);
      await vm.addSet(we);
    }

    test('önceki antrenmanda 60 × 10 varken 62,5 × 8 eklemek rekor bildirir', () async {
      await createPreviousWithBench([(60, 10)]);
      final workout = await repo.createWorkout(startedAt: DateTime(2026, 10, 17, 18));
      final we = await repo.addExerciseToWorkout(workout.id, bench.id);
      final vm = await loadedVm(workout.id);

      await addSetWith(vm, we.id, 62.5, 8);

      expect(vm.pendingRecordMessage, 'Yeni rekor: 62,5 kg × 8');
      final added = vm.detail!.exercises.single.sets.last;
      expect(vm.isRecordSet(bench.id, added), isTrue);
      vm.dispose();
    });

    test('50 × 10 eklemek bildirim üretmez ve rekor değildir', () async {
      await createPreviousWithBench([(60, 10)]);
      final workout = await repo.createWorkout(startedAt: DateTime(2026, 10, 17, 18));
      final we = await repo.addExerciseToWorkout(workout.id, bench.id);
      final vm = await loadedVm(workout.id);

      await addSetWith(vm, we.id, 50, 10);

      expect(vm.pendingRecordMessage, isNull);
      expect(vm.isRecordSet(bench.id, vm.detail!.exercises.single.sets.last), isFalse);
      vm.dispose();
    });

    test('ilk kez yapılan hareketin hiçbir seti rekor değildir', () async {
      final workout = await repo.createWorkout(startedAt: DateTime(2026, 10, 17, 18));
      final we = await repo.addExerciseToWorkout(workout.id, squat.id);
      final vm = await loadedVm(workout.id);

      await addSetWith(vm, we.id, 120, 5);

      expect(vm.pendingRecordMessage, isNull);
      expect(vm.isRecordSet(squat.id, vm.detail!.exercises.single.sets.last), isFalse);
      vm.dispose();
    });

    test('aynı antrenmandaki iki rekor set ikisi de rekordur', () async {
      await createPreviousWithBench([(60, 10)]);
      final workout = await repo.createWorkout(startedAt: DateTime(2026, 10, 17, 18));
      final we = await repo.addExerciseToWorkout(workout.id, bench.id);
      final vm = await loadedVm(workout.id);

      await addSetWith(vm, we.id, 62.5, 8);
      await addSetWith(vm, we.id, 65, 6);

      final sets = vm.detail!.exercises.single.sets;
      expect(vm.isRecordSet(bench.id, sets[0]), isTrue);
      expect(vm.isRecordSet(bench.id, sets[1]), isTrue);
      vm.dispose();
    });

    test('sonraki tarihli daha ağır antrenman bu seti rekor olmaktan çıkarmaz', () async {
      await createPreviousWithBench([(60, 10)]);
      final workout = await repo.createWorkout(startedAt: DateTime(2026, 10, 10, 18));
      final we = await repo.addExerciseToWorkout(workout.id, bench.id);
      await repo.addSet(we.id, weightKg: 62.5, reps: 8);
      final later = await repo.createWorkout(startedAt: DateTime(2026, 10, 20, 18));
      final laterWe = await repo.addExerciseToWorkout(later.id, bench.id);
      await repo.addSet(laterWe.id, weightKg: 100, reps: 5);

      final vm = await loadedVm(workout.id);

      expect(vm.isRecordSet(bench.id, vm.detail!.exercises.single.sets.single), isTrue);
      vm.dispose();
    });

    test('repeatLastSet rekor setini kopyalarsa bildirir', () async {
      await createPreviousWithBench([(60, 10)]);
      final workout = await repo.createWorkout(startedAt: DateTime(2026, 10, 17, 18));
      final we = await repo.addExerciseToWorkout(workout.id, bench.id);
      await repo.addSet(we.id, weightKg: 62.5, reps: 8);
      final vm = await loadedVm(workout.id);
      expect(vm.pendingRecordMessage, isNull);

      await vm.repeatLastSet(we.id);

      expect(vm.pendingRecordMessage, 'Yeni rekor: 62,5 kg × 8');
      vm.dispose();
    });

    test('updateSet ile rekor değerine çıkarmak bildirir; load bildirmez', () async {
      await createPreviousWithBench([(60, 10)]);
      final workout = await repo.createWorkout(startedAt: DateTime(2026, 10, 17, 18));
      final we = await repo.addExerciseToWorkout(workout.id, bench.id);
      await repo.addSet(we.id, weightKg: 50, reps: 10);
      final vm = await loadedVm(workout.id);
      expect(vm.pendingRecordMessage, isNull);

      final set = vm.detail!.exercises.single.sets.single;
      await vm.updateSet(set.copyWith(weightKg: 62.5, reps: 8));
      expect(vm.pendingRecordMessage, 'Yeni rekor: 62,5 kg × 8');

      vm.clearPendingRecord();
      expect(vm.pendingRecordMessage, isNull);

      await vm.load();
      expect(vm.pendingRecordMessage, isNull);
      vm.dispose();
    });

    test('düzenlenen set rekor değilse bildirim üretmez', () async {
      await createPreviousWithBench([(60, 10)]);
      final workout = await repo.createWorkout(startedAt: DateTime(2026, 10, 17, 18));
      final we = await repo.addExerciseToWorkout(workout.id, bench.id);
      await repo.addSet(we.id, weightKg: 50, reps: 10);
      final vm = await loadedVm(workout.id);

      final set = vm.detail!.exercises.single.sets.single;
      await vm.updateSet(set.copyWith(weightKg: 40));

      expect(vm.pendingRecordMessage, isNull);
      vm.dispose();
    });
  });
}
