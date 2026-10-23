import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/exercise_detail/exercise_detail_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_workout_repository.dart';

class _FailingHistoryRepository extends FakeWorkoutRepository {
  @override
  Future<List<ExerciseSession>> getExerciseHistory(int exerciseId) async {
    throw Exception('veritabanı hatası');
  }
}

void main() {
  late FakeWorkoutRepository repository;

  setUp(() {
    repository = FakeWorkoutRepository();
  });

  /// [sets]: (ağırlık, tekrar) çiftleri.
  Future<Workout> workoutWith(
    Exercise exercise,
    DateTime at,
    List<(double, int)> sets,
  ) async {
    final workout = await repository.createWorkout(startedAt: at);
    final we = await repository.addExerciseToWorkout(workout.id, exercise.id);
    for (final (kg, reps) in sets) {
      await repository.addSet(we.id, weightKg: kg, reps: reps);
    }
    return workout;
  }

  test('ilk durumda yükleniyor ve boş', () async {
    final bench = await repository.createExercise('Bench Press', MuscleGroup.chest);
    final viewModel = ExerciseDetailViewModel(repository, exercise: bench);
    addTearDown(viewModel.dispose);

    expect(viewModel.isLoading, isTrue);
    expect(viewModel.isEmpty, isTrue);
    expect(viewModel.selectedMetric, ProgressMetric.estimatedOneRepMax);
  });

  test('load geçmişi, değerleri ve rekorları hesaplar', () async {
    final bench = await repository.createExercise('Bench Press', MuscleGroup.chest);
    final first = await workoutWith(bench, DateTime(2026, 10, 1), [(60, 10)]);
    final second = await workoutWith(bench, DateTime(2026, 10, 8), [(70, 5), (65, 8)]);
    final viewModel = ExerciseDetailViewModel(repository, exercise: bench);
    addTearDown(viewModel.dispose);

    await viewModel.load();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.isEmpty, isFalse);
    expect(viewModel.isBodyweight, isFalse);
    // Grafik eskiden yeniye, liste yeniden eskiye.
    expect(viewModel.stats.map((s) => s.workout.id), [first.id, second.id]);
    expect(
      viewModel.sessionsNewestFirst.map((s) => s.workout.id),
      [second.id, first.id],
    );
    // 60×10 → 80; 65×8 → 82,33 (70×5 → 81,67'den yüksek).
    expect(viewModel.values[0], 80);
    expect(viewModel.values[1], closeTo(82.33, 0.01));
    expect(viewModel.records.heaviest!.value, 70);
    expect(viewModel.records.heaviest!.workout.id, second.id);
  });

  test('selectMetric değerleri değiştirir ve dinleyicileri uyarır', () async {
    final bench = await repository.createExercise('Bench Press', MuscleGroup.chest);
    await workoutWith(bench, DateTime(2026, 10, 1), [(60, 10), (60, 8)]);
    final viewModel = ExerciseDetailViewModel(repository, exercise: bench);
    addTearDown(viewModel.dispose);
    await viewModel.load();

    var notified = 0;
    viewModel.addListener(() => notified++);

    viewModel.selectMetric(ProgressMetric.volume);
    expect(viewModel.selectedMetric, ProgressMetric.volume);
    expect(viewModel.values, [1080]);

    viewModel.selectMetric(ProgressMetric.heaviest);
    expect(viewModel.values, [60]);
    expect(notified, 2);

    // Ağırlıklı harekette tekrar metriği sunulmaz.
    viewModel.selectMetric(ProgressMetric.reps);
    expect(viewModel.selectedMetric, ProgressMetric.heaviest);
    expect(notified, 2);
  });

  test('ağırlıksız harekette yalnızca tekrar metriği vardır', () async {
    final pullUp = await repository.createExercise('Barfiks', MuscleGroup.back);
    await workoutWith(pullUp, DateTime(2026, 10, 1), [(0, 8), (0, 10)]);
    await workoutWith(pullUp, DateTime(2026, 10, 8), [(0, 12)]);
    final viewModel = ExerciseDetailViewModel(repository, exercise: pullUp);
    addTearDown(viewModel.dispose);

    await viewModel.load();

    expect(viewModel.isBodyweight, isTrue);
    expect(viewModel.availableMetrics, [ProgressMetric.reps]);
    expect(viewModel.selectedMetric, ProgressMetric.reps);
    expect(viewModel.values, [10, 12]);
    expect(viewModel.records.mostReps!.value, 12);
  });

  test('yükleme hatasında Türkçe mesaj gösterilir', () async {
    final failing = _FailingHistoryRepository();
    final bench = await failing.createExercise('Bench Press', MuscleGroup.chest);
    final viewModel = ExerciseDetailViewModel(failing, exercise: bench);
    addTearDown(viewModel.dispose);

    await viewModel.load();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, 'Hareket geçmişi yüklenemedi.');

    viewModel.clearError();
    expect(viewModel.errorMessage, isNull);
  });

  group('updateExercise', () {
    test('başarılı güncelleme exercise değerini değiştirir ve dinleyicileri uyarır', () async {
      final bench = await repository.createExercise('Bench Press', MuscleGroup.chest);
      final viewModel = ExerciseDetailViewModel(repository, exercise: bench);
      addTearDown(viewModel.dispose);
      var notified = 0;
      viewModel.addListener(() => notified++);

      final ok = await viewModel.updateExercise('Dumbbell Press', MuscleGroup.arms);

      expect(ok, isTrue);
      expect(viewModel.exercise.id, bench.id);
      expect(viewModel.exercise.name, 'Dumbbell Press');
      expect(viewModel.exercise.muscleGroup, MuscleGroup.arms);
      expect(viewModel.errorMessage, isNull);
      expect(notified, 1);
    });

    test('aynı ad başka hareketle çakışırsa mesaj gösterilir ve false döner', () async {
      await repository.createExercise('Squat', MuscleGroup.legs);
      final bench = await repository.createExercise('Bench Press', MuscleGroup.chest);
      final viewModel = ExerciseDetailViewModel(repository, exercise: bench);
      addTearDown(viewModel.dispose);

      final ok = await viewModel.updateExercise('squat', MuscleGroup.chest);

      expect(ok, isFalse);
      expect(viewModel.errorMessage, 'Bu adda bir hareket zaten var.');
      expect(viewModel.exercise, bench);
    });

    test('değer değişmediyse repository çağrılmaz', () async {
      final counting = _CountingRepository();
      final bench = await counting.createExercise('Bench Press', MuscleGroup.chest);
      final viewModel = ExerciseDetailViewModel(counting, exercise: bench);
      addTearDown(viewModel.dispose);

      final ok = await viewModel.updateExercise('  Bench Press ', MuscleGroup.chest);

      expect(ok, isTrue);
      expect(counting.updateCalls, 0);
    });

    test('beklenmeyen hata genel Türkçe mesaj gösterir', () async {
      final failing = _FailingUpdateRepository();
      final bench = await failing.createExercise('Bench Press', MuscleGroup.chest);
      final viewModel = ExerciseDetailViewModel(failing, exercise: bench);
      addTearDown(viewModel.dispose);

      final ok = await viewModel.updateExercise('Dumbbell Press', MuscleGroup.arms);

      expect(ok, isFalse);
      expect(viewModel.errorMessage, 'Hareket güncellenemedi.');
      expect(viewModel.exercise, bench);
    });
  });
}

class _CountingRepository extends FakeWorkoutRepository {
  int updateCalls = 0;

  @override
  Future<Exercise> updateExercise(
    int id, {
    required String name,
    required MuscleGroup muscleGroup,
  }) {
    updateCalls++;
    return super.updateExercise(id, name: name, muscleGroup: muscleGroup);
  }
}

class _FailingUpdateRepository extends FakeWorkoutRepository {
  @override
  Future<Exercise> updateExercise(
    int id, {
    required String name,
    required MuscleGroup muscleGroup,
  }) async {
    throw Exception('veritabanı hatası');
  }
}
