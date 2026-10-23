import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/program_repository.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/ui/core/formatters.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/history/history_screen.dart';
import 'package:exercise_tracking_app/ui/workout/workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  late FakeWorkoutRepository repository;
  late FakeProgramRepository programs;

  setUp(() {
    repository = FakeWorkoutRepository();
    programs = FakeProgramRepository(repository);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutRepository>.value(value: repository),
          Provider<ProgramRepository>.value(value: programs),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemeId.darkOrange),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Yarının haftanın günü (1…7).
  int tomorrowWeekday() {
    final today = DateTime.now().weekday;
    return today == DateTime.sunday ? DateTime.monday : today + 1;
  }

  /// Bugünün gününe "Göğüs günü" (1 hareket), yarının gününe "Sırt günü" (2 hareket) koyan etkin program kurar.
  /// [withDays] false ise programın günü olmaz.
  Future<void> createActiveProgram({bool withDays = true}) async {
    final bench = await repository.createExercise('Bench', MuscleGroup.chest);
    final row = await repository.createExercise('Row', MuscleGroup.back);
    final program = await programs.createProgram('Üst/Alt');
    if (!withDays) return;

    final todayDay = await programs.addDay(
      program.id,
      'Göğüs günü',
      weekday: DateTime.now().weekday,
    );
    final otherDay = await programs.addDay(
      program.id,
      'Sırt günü',
      weekday: tomorrowWeekday(),
    );
    await programs.addDayExercise(
      todayDay.id,
      bench.id,
      const ExerciseTarget(sets: 3, reps: 10, weightKg: 60),
    );
    await programs.addDayExercise(
      otherDay.id,
      row.id,
      const ExerciseTarget(sets: 3, reps: 12),
    );
    await programs.addDayExercise(
      otherDay.id,
      bench.id,
      const ExerciseTarget(sets: 4, reps: 8),
    );
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

  testWidgets('etkin program yoksa FAB doğrudan antrenman açar',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Antrenman başlat'));
    await tester.pumpAndSettle();

    final workouts = await tester.runAsync(repository.getWorkoutSummaries);
    expect(workouts, hasLength(1));
    expect(find.byType(WorkoutScreen), findsOneWidget);
    expect(find.text('Boş antrenman'), findsNothing);
  });

  testWidgets('programın hiç günü yoksa FAB doğrudan boş antrenman açar',
      (tester) async {
    await createActiveProgram(withDays: false);
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Antrenman başlat'));
    await tester.pumpAndSettle();

    final workouts = await tester.runAsync(repository.getWorkoutSummaries);
    expect(workouts, hasLength(1));
    expect(workouts!.single.workout.title, isNull);
    expect(find.byType(WorkoutScreen), findsOneWidget);
  });

  testWidgets('etkin program varken FAB seçim sayfasını açar; bugünün günü vurgulanır',
      (tester) async {
    await createActiveProgram();
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Antrenman başlat'));
    await tester.pumpAndSettle();

    expect(find.text('Antrenman başlat'), findsNWidgets(2));
    expect(find.text('Bugün · Göğüs günü'), findsOneWidget);
    expect(find.text('Sırt günü'), findsOneWidget);
    expect(find.text('Boş antrenman'), findsOneWidget);
    expect(find.byType(WorkoutScreen), findsNothing);
  });

  testWidgets('seçim sayfasında gün satırları gün adı, haftanın günü ve hareket sayısını gösterir',
      (tester) async {
    await createActiveProgram();
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Antrenman başlat'));
    await tester.pumpAndSettle();

    // Bugünün günü hem vurgulu düğmede hem listede (1 hareket); yarınki gün listede (2 hareket).
    expect(find.text('1 hareket'), findsOneWidget);
    expect(
      find.text('${formatWeekday(DateTime.now().weekday)} · 1 hareket'),
      findsOneWidget,
    );
    expect(
      find.text('${formatWeekday(tomorrowWeekday())} · 2 hareket'),
      findsOneWidget,
    );
  });

  testWidgets('bir gün seçilince o günün adıyla antrenman ekranı açılır',
      (tester) async {
    await createActiveProgram();
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Antrenman başlat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sırt günü'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutScreen), findsOneWidget);
    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Sırt günü'),
    );
    expect(appBarTitle, findsWidgets);
    final workouts = await tester.runAsync(repository.getWorkoutSummaries);
    expect(workouts, hasLength(1));
    expect(workouts!.single.exerciseCount, 2);
  });

  testWidgets('Boş antrenman seçeneği boş antrenman açar', (tester) async {
    await createActiveProgram();
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Antrenman başlat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boş antrenman'));
    await tester.pumpAndSettle();

    final workouts = await tester.runAsync(repository.getWorkoutSummaries);
    expect(workouts, hasLength(1));
    expect(workouts!.single.workout.title, isNull);
    expect(find.byType(WorkoutScreen), findsOneWidget);
  });

  testWidgets('seçim sayfası dar ekranda (360x780, yazı 1.3) taşmaz',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await createActiveProgram();
    await pumpScreen(tester, textScale: 1.3);

    await tester.tap(find.byTooltip('Antrenman başlat'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bugün · Göğüs günü'), findsOneWidget);
  });

  testWidgets('Hareketler simgesi artık AppBar\'da yok (sekme oldu)',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byTooltip('Hareketler'), findsNothing);
    expect(find.byTooltip('Ayarlar'), findsOneWidget);
  });

  testWidgets('farklı haftalardaki antrenmanlar her hafta için başlık gösterir',
      (tester) async {
    final bench = await repository.createExercise('Bench', MuscleGroup.chest);
    // 2026-10-12 Pazartesi: 12–18 Ekim haftası (2 antrenman, 3 set).
    final first = await repository.createWorkout(
      title: 'Hafta bir A',
      startedAt: DateTime(2026, 10, 13, 18),
    );
    final firstEntry =
        await repository.addExerciseToWorkout(first.id, bench.id);
    await repository.addSet(firstEntry.id, weightKg: 60, reps: 10);
    final second = await repository.createWorkout(
      title: 'Hafta bir B',
      startedAt: DateTime(2026, 10, 14, 18),
    );
    final secondEntry =
        await repository.addExerciseToWorkout(second.id, bench.id);
    await repository.addSet(secondEntry.id, weightKg: 60, reps: 8);
    await repository.addSet(secondEntry.id, weightKg: 60, reps: 6);
    // 2026-10-19 Pazartesi: 19–25 Ekim haftası (1 antrenman, 2 set).
    final third = await repository.createWorkout(
      title: 'Hafta iki',
      startedAt: DateTime(2026, 10, 20, 18),
    );
    final thirdEntry = await repository.addExerciseToWorkout(third.id, bench.id);
    await repository.addSet(thirdEntry.id, weightKg: 70, reps: 5);
    await repository.addSet(thirdEntry.id, weightKg: 70, reps: 5);

    await pumpScreen(tester);

    expect(find.text(formatWeekRange(DateTime(2026, 10, 12))), findsOneWidget);
    expect(find.text(formatWeekRange(DateTime(2026, 10, 19))), findsOneWidget);
    expect(find.text('2 antrenman · 3 set'), findsOneWidget);
    expect(find.text('1 antrenman · 2 set'), findsOneWidget);
    expect(find.text('Hafta bir A'), findsOneWidget);
    expect(find.text('Hafta iki'), findsOneWidget);
  });

  testWidgets('hafta başlığı 360 × 780 ekranda yazı 1.3 iken taşmaz',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bench = await repository.createExercise('Bench', MuscleGroup.chest);
    final workout = await repository.createWorkout(
      title: 'Uzun başlıklı antrenman',
      startedAt: DateTime(2025, 12, 29, 18),
    );
    final entry = await repository.addExerciseToWorkout(workout.id, bench.id);
    await repository.addSet(entry.id, weightKg: 60, reps: 10);

    await pumpScreen(tester, textScale: 1.3);

    expect(find.text(formatWeekRange(DateTime(2025, 12, 29))), findsOneWidget);
    expect(tester.takeException(), isNull);
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
