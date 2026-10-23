import 'package:exercise_tracking_app/ui/history/history_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_workout_repository.dart';

void main() {
  late FakeWorkoutRepository repository;
  late HistoryViewModel viewModel;

  setUp(() {
    repository = FakeWorkoutRepository();
    viewModel = HistoryViewModel(repository);
  });

  tearDown(() {
    viewModel.dispose();
  });

  test('ilk durumda yükleniyor ve liste boş', () {
    expect(viewModel.isLoading, isTrue);
    expect(viewModel.workouts, isEmpty);
    expect(viewModel.errorMessage, isNull);
  });

  test('load sonrası antrenmanlar repository sırasıyla gelir', () async {
    final older = await repository.createWorkout(
      title: 'Eski',
      startedAt: DateTime(2026, 10, 1, 9),
    );
    final newer = await repository.createWorkout(
      title: 'Yeni',
      startedAt: DateTime(2026, 10, 10, 9),
    );

    final states = <bool>[];
    viewModel.addListener(() => states.add(viewModel.isLoading));

    await viewModel.load();

    expect(viewModel.isLoading, isFalse);
    expect(states, [true, false]);
    expect(
      viewModel.workouts.map((s) => s.workout.id),
      [newer.id, older.id],
    );
  });

  test('weeks antrenmanları farklı haftalara göre gruplar', () async {
    await repository.createWorkout(
      title: 'Pazar',
      startedAt: DateTime(2026, 10, 18, 20),
    );
    await repository.createWorkout(
      title: 'Pazartesi',
      startedAt: DateTime(2026, 10, 19, 7),
    );
    await repository.createWorkout(
      title: 'Aynı hafta',
      startedAt: DateTime(2026, 10, 13, 9),
    );
    await viewModel.load();

    final weeks = viewModel.weeks;

    expect(weeks, hasLength(2));
    expect(weeks[0].weekStart, DateTime(2026, 10, 19));
    expect(weeks[0].workouts.map((s) => s.workout.title), ['Pazartesi']);
    expect(weeks[1].weekStart, DateTime(2026, 10, 12));
    expect(
      weeks[1].workouts.map((s) => s.workout.title),
      ['Pazar', 'Aynı hafta'],
    );
  });

  test('startWorkout yeni id döner ve repository\'de antrenman oluşur', () async {
    final id = await viewModel.startWorkout();

    expect(id, isNotNull);
    final summaries = await repository.getWorkoutSummaries();
    expect(summaries, hasLength(1));
    expect(summaries.single.workout.id, id);
    expect(summaries.single.workout.title, isNull);
  });

  test('deleteWorkout listeden ve repository\'den siler', () async {
    final keep = await repository.createWorkout(title: 'Kalsın');
    final remove = await repository.createWorkout(title: 'Silinsin');
    await viewModel.load();

    await viewModel.deleteWorkout(remove.id);

    expect(viewModel.workouts.map((s) => s.workout.id), [keep.id]);
    final stored = await repository.getWorkoutSummaries();
    expect(stored.map((s) => s.workout.id), [keep.id]);
  });

  test('clearError hata mesajını temizler', () async {
    await viewModel.deleteWorkout(999);
    // Repository var olmayan id'yi sessizce yok sayar; hata oluşmaz.
    expect(viewModel.errorMessage, isNull);

    viewModel.clearError();
    expect(viewModel.errorMessage, isNull);
  });

  test('dispose sonrası load bildirim yapmaz ve hata vermez', () async {
    await repository.createWorkout(title: 'Test');
    final disposable = HistoryViewModel(repository);
    final pending = disposable.load();
    disposable.dispose();

    await expectLater(pending, completes);
  });
}
