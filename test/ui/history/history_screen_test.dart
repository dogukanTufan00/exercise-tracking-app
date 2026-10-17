import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/ui/core/formatters.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/exercises/exercises_screen.dart';
import 'package:exercise_tracking_app/ui/history/history_screen.dart';
import 'package:exercise_tracking_app/ui/workout/workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_workout_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  late FakeWorkoutRepository repository;

  setUp(() {
    repository = FakeWorkoutRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      Provider<WorkoutRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: buildAppTheme(AppThemeId.darkOrange),
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('boşken boş durum metni görünür', (tester) async {
    await pumpScreen(tester);

    expect(find.text('İlk antrenmanını başlat'), findsOneWidget);
    expect(find.text('Antrenman başlat'), findsOneWidget);
  });

  testWidgets('başlıklı antrenman kartında başlık, sayılar ve kas grupları görünür',
      (tester) async {
    final bench = await repository.createExercise('Bench', MuscleGroup.chest);
    final row = await repository.createExercise('Row', MuscleGroup.back);
    final workout = await repository.createWorkout(
      title: 'Üst gövde',
      startedAt: DateTime(2026, 10, 17, 18, 30),
    );
    final benchEntry =
        await repository.addExerciseToWorkout(workout.id, bench.id);
    final rowEntry = await repository.addExerciseToWorkout(workout.id, row.id);
    await repository.addSet(benchEntry.id, weightKg: 60, reps: 10);
    await repository.addSet(benchEntry.id, weightKg: 60, reps: 8);
    await repository.addSet(rowEntry.id, weightKg: 40, reps: 12);

    await pumpScreen(tester);

    expect(find.text('Üst gövde'), findsOneWidget);
    expect(find.text('17 Eki'), findsOneWidget);
    expect(find.text('2 hareket · 3 set'), findsOneWidget);
    expect(find.text('Göğüs'), findsOneWidget);
    expect(find.text('Sırt'), findsOneWidget);
    expect(find.text('İlk antrenmanını başlat'), findsNothing);
  });

  testWidgets('başlıksız antrenmanda tarih metni başlık olarak görünür',
      (tester) async {
    final startedAt = DateTime(2026, 10, 17, 18, 30);
    await repository.createWorkout(startedAt: startedAt);

    await pumpScreen(tester);

    expect(find.text(formatWorkoutDate(startedAt)), findsOneWidget);
    expect(find.text('0 hareket · 0 set'), findsOneWidget);
  });

  testWidgets('FAB antrenman oluşturur ve antrenman ekranını açar',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Antrenman başlat'));
    await tester.pumpAndSettle();

    final workouts = await tester.runAsync(repository.getWorkoutSummaries);
    expect(workouts, hasLength(1));
    expect(find.byType(WorkoutScreen), findsOneWidget);
  });

  testWidgets('Hareketler ikonu Hareketler ekranını açar', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Hareketler'));
    await tester.pumpAndSettle();

    expect(find.byType(ExercisesScreen), findsOneWidget);
    expect(find.text('Hareketler'), findsWidgets);
  });

  testWidgets('uzun basma, Sil ve kart kaybolur', (tester) async {
    await repository.createWorkout(title: 'Silinecek');
    await pumpScreen(tester);

    await tester.longPress(find.text('Silinecek'));
    await tester.pumpAndSettle();

    expect(find.text('Antrenman silinsin mi?'), findsOneWidget);

    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Silinecek'), findsNothing);
    expect(find.text('Antrenman silindi'), findsOneWidget);
  });
}
