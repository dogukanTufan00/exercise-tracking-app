import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/program/day_edit_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  late FakeWorkoutRepository workouts;
  late FakeProgramRepository repository;
  late int programId;
  late int dayId;
  late Exercise bench;
  late Exercise squat;

  setUp(() async {
    workouts = FakeWorkoutRepository();
    repository = FakeProgramRepository(workouts);
    programId = (await repository.createProgram('Üst/Alt')).id;
    dayId = (await repository.addDay(programId, 'Göğüs', weekday: DateTime.monday)).id;
    bench = await workouts.createExercise('Bench', MuscleGroup.chest);
    squat = await workouts.createExercise('Squat', MuscleGroup.legs);
  });

  DayEditViewModel newViewModel([int? id]) => DayEditViewModel(repository, id ?? dayId);

  test('yükleme günü ve hareketlerini sırayla getirir', () async {
    await repository.addDayExercise(dayId, bench.id, const ExerciseTarget(sets: 3, reps: 10));
    await repository.addDayExercise(dayId, squat.id, const ExerciseTarget(sets: 4, reps: 8, weightKg: 60));
    final viewModel = newViewModel();

    await viewModel.load();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.day?.name, 'Göğüs');
    expect(viewModel.day?.weekday, DateTime.monday);
    expect([for (final e in viewModel.exercises) e.exercise.name], ['Bench', 'Squat']);
  });

  test('bulunmayan gün için day null kalır', () async {
    final viewModel = newViewModel(999);

    await viewModel.load();

    expect(viewModel.day, isNull);
    expect(viewModel.exercises, isEmpty);
    expect(viewModel.errorMessage, isNull);
  });

  test('gün adı kırpılarak değişir; boş ad reddedilir', () async {
    final viewModel = newViewModel();
    await viewModel.load();

    expect(await viewModel.rename('   '), isFalse);
    expect(viewModel.day?.name, 'Göğüs');

    expect(await viewModel.rename('  Üst Gövde  '), isTrue);
    expect(viewModel.day?.name, 'Üst Gövde');
    final stored = await repository.getProgramDetail(programId);
    expect(stored?.days.single.day.name, 'Üst Gövde');
  });

  test('planlanan gün değişir ve esnek (null) seçilebilir', () async {
    final viewModel = newViewModel();
    await viewModel.load();

    expect(await viewModel.setWeekday(3), isTrue);
    expect(viewModel.day?.weekday, 3);

    expect(await viewModel.setWeekday(null), isTrue);
    expect(viewModel.day?.weekday, isNull);
    expect(viewModel.day?.name, 'Göğüs');
  });

  test('hareket ekleme, hedef güncelleme ve çıkarma', () async {
    final viewModel = newViewModel();
    await viewModel.load();

    expect(await viewModel.addExercise(bench.id, const ExerciseTarget(sets: 3, reps: 10)), isTrue);
    expect(await viewModel.addExercise(squat.id, const ExerciseTarget(sets: 3, reps: 5)), isTrue);
    expect(viewModel.exercises, hasLength(2));

    final benchEntry = viewModel.exercises.first;
    expect(
      await viewModel.updateTarget(
        benchEntry.dayExercise.id,
        const ExerciseTarget(sets: 4, reps: 6, weightKg: 62.5),
      ),
      isTrue,
    );
    expect(viewModel.exercises.first.dayExercise.target.weightKg, 62.5);
    expect(viewModel.exercises.first.dayExercise.target.sets, 4);

    expect(await viewModel.removeExercise(benchEntry.dayExercise.id), isTrue);
    expect([for (final e in viewModel.exercises) e.exercise.name], ['Squat']);
    expect(viewModel.exercises.single.dayExercise.position, 0);
  });

  test('moveExercise sırayı değiştirir ve sınırları aşmaz', () async {
    await repository.addDayExercise(dayId, bench.id, const ExerciseTarget(sets: 3, reps: 10));
    await repository.addDayExercise(dayId, squat.id, const ExerciseTarget(sets: 3, reps: 5));
    final viewModel = newViewModel();
    await viewModel.load();

    expect(await viewModel.moveExercise(0, -1), isFalse);
    expect(await viewModel.moveExercise(1, 1), isFalse);

    expect(await viewModel.moveExercise(1, -1), isTrue);
    expect([for (final e in viewModel.exercises) e.exercise.name], ['Squat', 'Bench']);

    expect(await viewModel.moveExercise(0, 1), isTrue);
    expect([for (final e in viewModel.exercises) e.exercise.name], ['Bench', 'Squat']);
  });

  test('gün silinir ve başarı döner', () async {
    await repository.addDayExercise(dayId, bench.id, const ExerciseTarget(sets: 3, reps: 10));
    final viewModel = newViewModel();
    await viewModel.load();

    expect(await viewModel.deleteDay(), isTrue);

    expect(await repository.getProgramDetail(programId), isNotNull);
    expect((await repository.getProgramDetail(programId))!.days, isEmpty);
    expect(viewModel.day, isNull);
  });

  test('yazma hatası errorMessage olarak kalır ve clearError ile temizlenir', () async {
    final viewModel = newViewModel();
    await viewModel.load();

    // Olmayan hareket katalogda yok: repository ArgumentError fırlatır.
    expect(await viewModel.addExercise(9999, const ExerciseTarget(sets: 3, reps: 10)), isFalse);
    expect(viewModel.errorMessage, 'Hareket eklenemedi');

    viewModel.clearError();
    expect(viewModel.errorMessage, isNull);
  });

  test('dispose sonrası bildirim hata vermez', () async {
    final viewModel = newViewModel();
    final loading = viewModel.load();
    viewModel.dispose();

    await expectLater(loading, completes);
  });
}
