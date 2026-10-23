import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/program_repository.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/core/widgets/empty_state.dart';
import 'package:exercise_tracking_app/ui/program/day_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_workout_repository.dart';

/// Ekranı, iki repository sağlayıcısıyla birlikte kurar.
Widget _app({
  required WorkoutRepository workouts,
  required ProgramRepository programs,
  required Widget home,
  double textScale = 1,
}) {
  return MultiProvider(
    providers: [
      Provider<WorkoutRepository>.value(value: workouts),
      Provider<ProgramRepository>.value(value: programs),
    ],
    child: MaterialApp(
      theme: buildAppTheme(AppThemeId.darkOrange),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  late FakeWorkoutRepository workouts;
  late FakeProgramRepository programs;
  late int dayId;

  setUp(() async {
    workouts = FakeWorkoutRepository();
    programs = FakeProgramRepository(workouts);
    final programId = (await programs.createProgram('Üst/Alt')).id;
    dayId = (await programs.addDay(programId, 'Göğüs', weekday: DateTime.monday)).id;
  });

  Future<void> pumpScreen(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      _app(
        workouts: workouts,
        programs: programs,
        home: DayEditScreen(dayId: dayId),
        textScale: textScale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('başlıkta gün adı görünür; boş durum gösterilir', (tester) async {
    await pumpScreen(tester);

    expect(find.widgetWithText(AppBar, 'Göğüs'), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Henüz hareket yok'), findsOneWidget);
  });

  testWidgets('planlanan gün çipi seçilince gün kaydedilir', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sal'));
    await tester.pumpAndSettle();

    final detail = await programs.getProgramDetail((await programs.getPrograms()).single.id);
    expect(detail?.days.single.day.weekday, DateTime.tuesday);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sal')).selected, isTrue);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Esnek'));
    await tester.pumpAndSettle();
    final cleared = await programs.getProgramDetail((await programs.getPrograms()).single.id);
    expect(cleared?.days.single.day.weekday, isNull);
  });

  testWidgets('hareket ekle: picker açılır, hareket seçilir, hedef kaydedilir', (tester) async {
    await workouts.createExercise('Bench', MuscleGroup.chest);
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Hareket ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Hareket seç'), findsOneWidget);

    await tester.tap(find.text('Bench'));
    await tester.pumpAndSettle();

    // Hedef diyaloğu varsayılan 3 × 10 ile açılır.
    expect(find.widgetWithText(AlertDialog, 'Bench'), findsOneWidget);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Bench'), findsOneWidget);
    expect(find.text('3 × 10'), findsOneWidget);
    expect(find.text('Henüz hareket yok'), findsNothing);
  });

  testWidgets('hedef diyaloğunda ağırlık anahtarı açılır ve satırda görünür', (tester) async {
    final bench = await workouts.createExercise('Bench', MuscleGroup.chest);
    await programs.addDayExercise(
      dayId,
      bench.id,
      const ExerciseTarget(sets: 3, reps: 10),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Bench'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('3 × 10 · 20 kg'), findsOneWidget);
  });

  testWidgets('⋮ menüsünden Yukarı taşı sırayı değiştirir', (tester) async {
    final bench = await workouts.createExercise('Bench', MuscleGroup.chest);
    final squat = await workouts.createExercise('Squat', MuscleGroup.legs);
    await programs.addDayExercise(dayId, bench.id, const ExerciseTarget(sets: 3, reps: 10));
    await programs.addDayExercise(dayId, squat.id, const ExerciseTarget(sets: 3, reps: 5));
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Hareket menüsü').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yukarı taşı'));
    await tester.pumpAndSettle();

    final names = [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title! as Text).data,
    ];
    expect(names, ['Squat', 'Bench']);
  });

  testWidgets('günü yeniden adlandırma başlığı günceller', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Günü yeniden adlandır'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Üst Gövde');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Üst Gövde'), findsOneWidget);
  });

  testWidgets('Günü sil onaylanınca gün silinir ve ekran kapanır', (tester) async {
    await tester.pumpWidget(
      _app(
        workouts: workouts,
        programs: programs,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DayEditScreen(dayId: dayId)),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Gün menüsü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Günü sil'));
    await tester.pumpAndSettle();
    expect(find.text('Gün ve hareketleri programdan silinecek.'), findsOneWidget);

    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(find.byType(DayEditScreen), findsNothing);
    final programId = (await programs.getPrograms()).single.id;
    expect((await programs.getProgramDetail(programId))?.days, isEmpty);
  });

  testWidgets('360 × 780 ve yazı 1.3 ile ekran ve hedef diyaloğu taşmaz', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bench = await workouts.createExercise('Bench Press Yüksek Eğim', MuscleGroup.chest);
    await programs.addDayExercise(dayId, bench.id, const ExerciseTarget(sets: 3, reps: 10, weightKg: 102.5));
    await pumpScreen(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('Bench Press').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Kaydet'), findsOneWidget);
  });
}
