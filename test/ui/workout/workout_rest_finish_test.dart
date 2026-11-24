import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/data/rest/rest_controller.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/workout/workout_screen.dart';
import 'package:exercise_tracking_app/ui/workout/workout_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_rest_notifier.dart';
import '../../fakes/fake_rest_store.dart';
import '../../fakes/fake_settings_repository.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  late FakeWorkoutRepository repository;
  late FakeRestStore store;
  late RestController controller;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 11, 20, 18, 0, 0);
    repository = FakeWorkoutRepository();
    store = FakeRestStore();
    controller = RestController(
      store: store,
      settings: FakeSettingsRepository(),
      notifier: FakeRestNotifier(),
      clock: () => now,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  /// Antrenman ve bir hareket oluşturur; (antrenman id, antrenmandaki hareket id) döner.
  Future<(int, int)> createWorkoutWithExercise({DateTime? startedAt}) async {
    final workout = await repository.createWorkout(startedAt: startedAt ?? now);
    final exercise = await repository.createExercise('Bench', MuscleGroup.chest);
    final added = await repository.addExerciseToWorkout(workout.id, exercise.id);
    return (workout.id, added.id);
  }

  group('WorkoutViewModel dinlenme ve bitirme', () {
    test('set eklenince dinlenme sayacı başlar', () async {
      final (workoutId, workoutExerciseId) = await createWorkoutWithExercise();
      await controller.load();
      final viewModel = WorkoutViewModel(
        repository,
        workoutId,
        restController: controller,
        clock: () => now,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await viewModel.addSet(workoutExerciseId);

      expect(store.rest?.workoutId, workoutId);
      expect(store.rest?.totalSeconds, 90);
    });

    test('set düzenleme dinlenme başlatmaz', () async {
      final (workoutId, workoutExerciseId) = await createWorkoutWithExercise();
      await controller.load();
      final viewModel = WorkoutViewModel(
        repository,
        workoutId,
        restController: controller,
        clock: () => now,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();
      await viewModel.addSet(workoutExerciseId);
      await controller.skip();

      final set = viewModel.detail!.exercises.single.sets.single;
      await viewModel.updateSet(set);

      expect(store.rest, isNull);
    });

    test('bitir bitiş saatini yazar ve dinlenmeyi durdurur', () async {
      final (workoutId, workoutExerciseId) = await createWorkoutWithExercise();
      await controller.load();
      final viewModel = WorkoutViewModel(
        repository,
        workoutId,
        restController: controller,
        clock: () => now,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();
      await viewModel.addSet(workoutExerciseId);

      final finished = await viewModel.finishWorkout();

      expect(finished, isTrue);
      final detail = await repository.getWorkoutDetail(workoutId);
      expect(detail!.workout.finishedAt, now);
      expect(store.rest, isNull);
      expect(viewModel.canFinish, isFalse);
    });

    test('12 saatten eski antrenman bitirilemez', () async {
      final (workoutId, _) = await createWorkoutWithExercise(
        startedAt: now.subtract(const Duration(hours: 13)),
      );
      final viewModel = WorkoutViewModel(
        repository,
        workoutId,
        clock: () => now,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      expect(viewModel.isRecent, isFalse);
      expect(viewModel.canFinish, isFalse);
    });

    test('yeni ve bitirilmemiş antrenman bitirilebilir', () async {
      final (workoutId, _) = await createWorkoutWithExercise(
        startedAt: now.subtract(const Duration(hours: 1)),
      );
      final viewModel = WorkoutViewModel(
        repository,
        workoutId,
        clock: () => now,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      expect(viewModel.canFinish, isTrue);
    });
  });

  group('WorkoutScreen "Bitir"', () {
    testWidgets('onay sonrası bitiş yazılır ve ekran kapanır', (tester) async {
      final (workoutId, _) = await createWorkoutWithExercise(
        startedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<WorkoutRepository>.value(value: repository),
            ChangeNotifierProvider<RestController>.value(value: controller),
          ],
          child: MaterialApp(
            theme: buildAppTheme(AppThemeId.darkOrange),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WorkoutScreen(workoutId: workoutId),
                  ),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      expect(find.text('Bitir'), findsOneWidget);
      await tester.tap(find.text('Bitir'));
      await tester.pumpAndSettle();
      expect(find.text('Bitiş saati kaydedilecek.'), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Bitir'),
      ));
      await tester.pumpAndSettle();

      final detail = await repository.getWorkoutDetail(workoutId);
      expect(detail!.workout.finishedAt, isNotNull);
      expect(find.text('aç'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('eski antrenmanda "Bitir" görünmez', (tester) async {
      final (workoutId, _) = await createWorkoutWithExercise(
        startedAt: DateTime.now().subtract(const Duration(hours: 13)),
      );

      await tester.pumpWidget(
        Provider<WorkoutRepository>.value(
          value: repository,
          child: MaterialApp(
            theme: buildAppTheme(AppThemeId.darkOrange),
            home: WorkoutScreen(workoutId: workoutId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bitir'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
