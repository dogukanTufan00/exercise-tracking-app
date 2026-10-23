import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/core/widgets/muscle_group_chip.dart';
import 'package:exercise_tracking_app/ui/exercise_detail/exercise_detail_screen.dart';
import 'package:exercise_tracking_app/ui/exercise_detail/exercise_detail_view_model.dart';
import 'package:exercise_tracking_app/ui/exercise_picker/exercise_picker_screen.dart';
import 'package:fl_chart/fl_chart.dart';
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

  /// [sets]: (ağırlık, tekrar) çiftleri.
  Future<void> workoutWith(
    Exercise exercise,
    DateTime at,
    List<(double, int)> sets,
  ) async {
    final workout = await repo.createWorkout(startedAt: at);
    final we = await repo.addExerciseToWorkout(workout.id, exercise.id);
    for (final (kg, reps) in sets) {
      await repo.addSet(we.id, weightKg: kg, reps: reps);
    }
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    Exercise exercise, {
    Size size = const Size(800, 1600),
    double textScale = 1.0,
  }) async {
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
          home: ExerciseDetailScreen(exercise: exercise),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('formatMetricValue birimi ekler ve 1RM\'i tek basamağa yuvarlar', () {
    expect(formatMetricValue(82.333, ProgressMetric.estimatedOneRepMax), '82,3 kg');
    expect(formatMetricValue(60, ProgressMetric.heaviest), '60 kg');
    expect(formatMetricValue(12, ProgressMetric.reps), '12 tekrar');
  });

  testWidgets('seti olmayan harekette boş durum görünür', (tester) async {
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);

    await pumpDetail(tester, bench);

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Henüz set yok'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('rekorlar, grafik ve antrenmanlar görünür', (tester) async {
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    await workoutWith(bench, DateTime(2026, 10, 1), [(60, 10)]);
    await workoutWith(bench, DateTime(2026, 10, 8), [(70, 5), (65, 8)]);

    await pumpDetail(tester, bench);

    expect(find.text('Kişisel rekorlar'), findsOneWidget);
    expect(find.text('70 kg'), findsOneWidget); // en ağır
    expect(find.text('82,3 kg'), findsOneWidget); // tahmini 1RM (65×8)
    expect(find.text('870 kg'), findsOneWidget); // en yüksek hacim (350 + 520)
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('70 kg × 5, 65 kg × 8'), findsOneWidget);
    expect(find.text('60 kg × 10'), findsOneWidget);
  });

  testWidgets('metrik seçimi değişince 1RM açıklaması kaybolur', (tester) async {
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    await workoutWith(bench, DateTime(2026, 10, 1), [(60, 10)]);
    await workoutWith(bench, DateTime(2026, 10, 8), [(62.5, 10)]);

    final semantics = tester.ensureSemantics();
    await pumpDetail(tester, bench);
    expect(find.textContaining('Epley'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Tahmini 1RM grafiği')), findsOneWidget);

    await tester.tap(find.text('Hacim'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Epley'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Hacim grafiği')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('tek antrenmanda grafik yerine bilgi metni görünür', (tester) async {
    final bench = await repo.createExercise('Bench Press', MuscleGroup.chest);
    await workoutWith(bench, DateTime(2026, 10, 1), [(60, 5)]);

    await pumpDetail(tester, bench);

    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('en az iki antrenman'), findsOneWidget);
  });

  testWidgets('ağırlıksız harekette tekrar rekoru gösterilir, metrik seçimi yok',
      (tester) async {
    final pullUp = await repo.createExercise('Barfiks', MuscleGroup.back);
    await workoutWith(pullUp, DateTime(2026, 10, 1), [(0, 8)]);
    await workoutWith(pullUp, DateTime(2026, 10, 8), [(0, 10)]);

    await pumpDetail(tester, pullUp);

    expect(find.text('En çok tekrar'), findsOneWidget);
    expect(find.text('10 tekrar'), findsOneWidget);
    expect(find.text('En ağır'), findsNothing);
    expect(find.byType(SegmentedButton<ProgressMetric>), findsNothing);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('telefon boyutunda (360x780, yazı 1.3) taşma olmaz', (tester) async {
    final bench = await repo.createExercise('Incline Dumbbell Press', MuscleGroup.chest);
    for (var day = 1; day <= 8; day++) {
      await workoutWith(bench, DateTime(2026, 9, day * 3), [
        (100 + day * 2.5, 8),
        (100 + day * 2.5, 6),
      ]);
    }

    await pumpDetail(
      tester,
      bench,
      size: const Size(360, 780),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('120 kg × 8, 120 kg × 6'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('düzenle → yeni ad AppBar\'da, yeni kas grubu etiketi görünür', (tester) async {
    final curl = await repo.createExercise('Biceps curl', MuscleGroup.legs);
    await workoutWith(curl, DateTime(2026, 10, 1), [(10, 10)]);

    await pumpDetail(tester, curl);
    await tester.tap(find.byTooltip('Hareketi düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Dumbbell Curl');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MuscleGroupChip, 'Kol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Dumbbell Curl')),
      findsOneWidget,
    );
    expect(find.widgetWithText(MuscleGroupChip, 'Kol'), findsOneWidget);
    expect(find.widgetWithText(MuscleGroupChip, 'Bacak'), findsNothing);
  });

  /// ⋮ menüsünden "Başka bir hareketle birleştir" seçeneğini açar.
  Future<void> openMergePicker(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Hareket seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başka bir hareketle birleştir'));
    await tester.pumpAndSettle();
  }

  /// Seçici ekranındaki bir hareket satırı (AppBar'daki aynı ad ile karışmasın diye).
  Finder pickerRow(String name) => find.descendant(
        of: find.byType(ExercisePickerScreen),
        matching: find.text(name),
      );

  testWidgets('birleştir: hedef detayı açılır, kaynağın antrenmanları orada görünür',
      (tester) async {
    final source = await repo.createExercise('Pecdec', MuscleGroup.chest);
    final target = await repo.createExercise('Pec deck', MuscleGroup.chest);
    await workoutWith(source, DateTime(2026, 10, 1), [(60, 10)]);
    await workoutWith(target, DateTime(2026, 10, 8), [(70, 5)]);

    await pumpDetail(tester, source);
    await openMergePicker(tester);
    await tester.tap(pickerRow('Pec deck'));
    await tester.pumpAndSettle();

    expect(find.text('Hareketler birleştirilsin mi?'), findsOneWidget);
    expect(find.textContaining('geri alınamaz'), findsOneWidget);
    await tester.tap(find.text('Birleştir'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Pec deck')),
      findsOneWidget,
    );
    expect(find.text('60 kg × 10'), findsOneWidget);
    expect(find.text('70 kg × 5'), findsOneWidget);
    expect(find.text('Hareketler birleştirildi'), findsOneWidget);
    expect(await repo.searchExercises('Pecdec'), isEmpty);
  });

  testWidgets('birleştir onayında Vazgeç hiçbir şeyi değiştirmez', (tester) async {
    final source = await repo.createExercise('Pecdec', MuscleGroup.chest);
    await repo.createExercise('Pec deck', MuscleGroup.chest);

    await pumpDetail(tester, source);
    await openMergePicker(tester);
    await tester.tap(pickerRow('Pec deck'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Pecdec')),
      findsOneWidget,
    );
    expect(find.text('Hareketler birleştirildi'), findsNothing);
    expect(await repo.searchExercises('Pecdec'), hasLength(1));
    expect(await repo.searchExercises('Pec deck'), hasLength(1));
  });

  testWidgets('aynı hareket seçilirse bilgi mesajı gösterilir, onay açılmaz', (tester) async {
    final source = await repo.createExercise('Pecdec', MuscleGroup.chest);

    await pumpDetail(tester, source);
    await openMergePicker(tester);
    await tester.tap(pickerRow('Pecdec'));
    await tester.pumpAndSettle();

    expect(find.text('Aynı hareket seçildi.'), findsOneWidget);
    expect(find.text('Hareketler birleştirilsin mi?'), findsNothing);
    expect(await repo.searchExercises('Pecdec'), hasLength(1));
  });
}
