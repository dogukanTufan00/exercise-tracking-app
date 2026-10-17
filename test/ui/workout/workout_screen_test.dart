import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/workout/workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_workout_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  late FakeWorkoutRepository repo;

  setUp(() {
    repo = FakeWorkoutRepository();
  });

  Future<void> pumpWorkout(
    WidgetTester tester,
    int workoutId, {
    Size size = const Size(800, 1600),
    double textScale = 1.0,
  }) async {
    // Hareket kartı ve düğmeler tek ekranda görünsün diye yüzeyi büyütür (varsayılan).
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      Provider<WorkoutRepository>.value(
        value: repo,
        child: MaterialApp(
          theme: buildAppTheme(AppThemeId.darkOrange),
          home: WorkoutScreen(workoutId: workoutId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hareketsiz antrenmanda boş durum görünür', (tester) async {
    final workout = await repo.createWorkout(title: 'Upper');

    await pumpWorkout(tester, workout.id);

    expect(find.text('İlk hareketini ekle'), findsOneWidget);
    expect(find.text('Hareket ekle'), findsOneWidget);
  });

  testWidgets('hareket ve setleri görünür', (tester) async {
    final workout = await repo.createWorkout(title: 'Upper');
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    final we = await repo.addExerciseToWorkout(workout.id, bench.id);
    await repo.addSet(we.id, weightKg: 60, reps: 10);

    await pumpWorkout(tester, workout.id);

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('60 kg × 10'), findsOneWidget);
    expect(find.text('İlk hareketini ekle'), findsNothing);
  });

  testWidgets('geçen sefer metni görünür', (tester) async {
    final previous = await repo.createWorkout(
      startedAt: DateTime(2026, 10, 1, 18),
    );
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    final prevWe = await repo.addExerciseToWorkout(previous.id, bench.id);
    await repo.addSet(prevWe.id, weightKg: 60, reps: 10);
    await repo.addSet(prevWe.id, weightKg: 65, reps: 8);

    final workout = await repo.createWorkout(
      title: 'Upper',
      startedAt: DateTime(2026, 10, 17, 18),
    );
    await repo.addExerciseToWorkout(workout.id, bench.id);

    await pumpWorkout(tester, workout.id);

    expect(find.text('Geçen sefer: 60 kg × 10, 65 kg × 8'), findsOneWidget);
  });

  testWidgets('Set ekle yeni set satırı ekler', (tester) async {
    final workout = await repo.createWorkout(title: 'Upper');
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    final we = await repo.addExerciseToWorkout(workout.id, bench.id);
    await repo.addSet(we.id, weightKg: 50, reps: 8);

    await pumpWorkout(tester, workout.id);
    expect(find.text('50 kg × 8'), findsOneWidget);

    // Taslak bu antrenmandaki son set olan 50 kg × 8'dir.
    await tester.tap(find.text('Set ekle'));
    await tester.pumpAndSettle();

    expect(find.text('50 kg × 8'), findsNWidgets(2));
  });

  testWidgets('başlık yoksa tarih, varsa başlık gösterilir', (tester) async {
    final workout = await repo.createWorkout(
      startedAt: DateTime(2026, 10, 17, 18, 30),
    );
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    await repo.addExerciseToWorkout(workout.id, bench.id);

    await pumpWorkout(tester, workout.id);

    expect(find.text('17 Ekim 2026 · 18:30'), findsWidgets);
    expect(find.text('Antrenman adı'), findsNothing);
  });

  testWidgets('başlığa dokununca ad diyaloğu açılır', (tester) async {
    final workout = await repo.createWorkout(title: 'Upper');
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    await repo.addExerciseToWorkout(workout.id, bench.id);

    await pumpWorkout(tester, workout.id);

    await tester.tap(find.text('Upper'));
    await tester.pumpAndSettle();

    expect(find.text('Antrenman adı'), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);
    expect(find.text('İptal'), findsOneWidget);
  });

  testWidgets('kapalı kartta özet görünür ve Set ekle görünmez', (tester) async {
    final workout = await repo.createWorkout(title: 'Upper');
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    final squat = await repo.createExercise('Squat', MuscleGroup.legs);
    final benchWe = await repo.addExerciseToWorkout(workout.id, bench.id);
    await repo.addSet(benchWe.id, weightKg: 10, reps: 10);
    await repo.addSet(benchWe.id, weightKg: 15, reps: 10);
    await repo.addSet(benchWe.id, weightKg: 12, reps: 12);
    await repo.addExerciseToWorkout(workout.id, squat.id);

    await pumpWorkout(tester, workout.id);

    // Yalnızca son kart (Squat) açık; bench'in özeti var, "Set ekle" tek.
    expect(find.text('3 set · 15 kg × 10'), findsOneWidget);
    expect(find.text('Set ekle'), findsOneWidget);
  });

  testWidgets('başlığa dokununca kapalı kart açılır', (tester) async {
    final workout = await repo.createWorkout(title: 'Upper');
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    final squat = await repo.createExercise('Squat', MuscleGroup.legs);
    final benchWe = await repo.addExerciseToWorkout(workout.id, bench.id);
    await repo.addSet(benchWe.id, weightKg: 15, reps: 10);
    await repo.addExerciseToWorkout(workout.id, squat.id);

    await pumpWorkout(tester, workout.id);
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('1 set · 15 kg × 10'), findsNothing);
    expect(find.text('Set ekle'), findsNWidgets(2));
  });

  testWidgets('setsiz kapalı kartta "Henüz set yok" ve not ikonu görünür',
      (tester) async {
    final workout = await repo.createWorkout(title: 'Upper');
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    final squat = await repo.createExercise('Squat', MuscleGroup.legs);
    final benchWe = await repo.addExerciseToWorkout(workout.id, bench.id);
    await repo.updateExerciseNote(benchWe.id, 'Formum bozuldu');
    await repo.addExerciseToWorkout(workout.id, squat.id);

    await pumpWorkout(tester, workout.id);

    expect(find.text('Henüz set yok'), findsOneWidget);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
  });

  testWidgets('telefon boyutunda (360x780, yazı 1.3) kartlar taşmaz',
      (tester) async {
    final workout = await repo.createWorkout(title: 'Upper');
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    final squat = await repo.createExercise('Squat', MuscleGroup.legs);
    final benchWe = await repo.addExerciseToWorkout(workout.id, bench.id);
    await repo.addSet(benchWe.id, weightKg: 60, reps: 10);
    await repo.addSet(benchWe.id, weightKg: 62.5, reps: 8);
    await repo.addExerciseToWorkout(workout.id, squat.id);

    await pumpWorkout(
      tester,
      workout.id,
      size: const Size(360, 780),
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Set ekle'), findsOneWidget);
  });
}
