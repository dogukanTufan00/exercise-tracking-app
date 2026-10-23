import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/program_repository.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/program/day_edit_screen.dart';
import 'package:exercise_tracking_app/ui/program/program_screen.dart';
import 'package:exercise_tracking_app/ui/program/programs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  late FakeWorkoutRepository workouts;
  late FakeProgramRepository programs;

  setUp(() {
    workouts = FakeWorkoutRepository();
    programs = FakeProgramRepository(workouts);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutRepository>.value(value: workouts),
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
          home: const ProgramScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Açık diyaloğa metni yazar ve onay düğmesine basar.
  Future<void> submitDialog(WidgetTester tester, String text, String confirm) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, confirm));
    await tester.pumpAndSettle();
  }

  /// "Üst/Alt" etkin programı; "Göğüs" (Pazartesi, Bench Press 3 × 10 · 40 kg) ve "Boş gün" günleriyle.
  Future<void> seedProgram() async {
    final bench = await workouts.createExercise('Bench Press', MuscleGroup.chest);
    final program = await programs.createProgram('Üst/Alt');
    final chest = await programs.addDay(program.id, 'Göğüs', weekday: DateTime.monday);
    await programs.addDayExercise(
      chest.id,
      bench.id,
      const ExerciseTarget(sets: 3, reps: 10, weightKg: 40),
    );
    await programs.addDay(program.id, 'Boş gün');
  }

  testWidgets('program yokken boş durum ve "Program oluştur" görünür', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Henüz program yok'), findsOneWidget);
    expect(find.text('Program oluştur'), findsOneWidget);
  });

  testWidgets('"Program oluştur" program adı sorar ve programı oluşturur', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Program oluştur'));
    await tester.pumpAndSettle();
    await submitDialog(tester, 'Üst/Alt', 'Oluştur');

    expect(find.text('Üst/Alt'), findsWidgets);
    expect(find.text('Henüz gün yok'), findsOneWidget);
    expect((await programs.getActiveProgramDetail())?.program.name, 'Üst/Alt');
  });

  testWidgets('günler, planlanan gün ve hedef satırları görünür', (tester) async {
    await seedProgram();
    await pumpScreen(tester);

    expect(find.text('Göğüs'), findsOneWidget);
    expect(find.text('Pazartesi'), findsOneWidget);
    expect(find.text('Boş gün'), findsOneWidget);
    expect(find.text('Esnek gün'), findsOneWidget);
    expect(find.text('Bench Press · 3 × 10 · 40 kg'), findsOneWidget);
    expect(find.text('Henüz hareket yok'), findsOneWidget);
  });

  testWidgets('gün ekle: ad sorulur, gün eklenir ve gün ekranı açılır', (tester) async {
    await seedProgram();
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Gün ekle'));
    await tester.pumpAndSettle();
    await submitDialog(tester, 'Sırt', 'Oluştur');

    expect(find.byType(DayEditScreen), findsOneWidget);
    final names = [
      for (final d in (await programs.getActiveProgramDetail())!.days) d.day.name,
    ];
    expect(names, ['Göğüs', 'Boş gün', 'Sırt']);
  });

  testWidgets('gün kartına dokunmak gün ekranını açar', (tester) async {
    await seedProgram();
    await pumpScreen(tester);

    await tester.tap(find.text('Göğüs'));
    await tester.pumpAndSettle();

    expect(find.byType(DayEditScreen), findsOneWidget);
  });

  testWidgets('sıralama menüsü günü aşağı taşır', (tester) async {
    await seedProgram();
    await pumpScreen(tester);

    expect(find.text('Yukarı taşı'), findsNothing);
    await tester.tap(find.byTooltip('Gün seçenekleri').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aşağı taşı'));
    await tester.pumpAndSettle();

    final chestY = tester.getTopLeft(find.text('Göğüs')).dy;
    final emptyDayY = tester.getTopLeft(find.text('Boş gün')).dy;
    expect(emptyDayY, lessThan(chestY));
  });

  testWidgets('program adı yeniden adlandırılır', (tester) async {
    await seedProgram();
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Program seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeniden adlandır'));
    await tester.pumpAndSettle();
    await submitDialog(tester, 'Yeni ad', 'Kaydet');

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Yeni ad')),
      findsOneWidget,
    );
  });

  testWidgets('program silme onaydan sonra yapılır', (tester) async {
    await seedProgram();
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Program seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programı sil'));
    await tester.pumpAndSettle();

    expect(
      find.text('Program ve tüm günleri silinecek. Bu programla yapılmış antrenmanlar kalır.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Henüz program yok'), findsOneWidget);
    expect(await programs.getPrograms(), isEmpty);
  });

  testWidgets('silme onayda vazgeçilirse program kalır', (tester) async {
    await seedProgram();
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Program seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programı sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Vazgeç'));
    await tester.pumpAndSettle();

    expect(find.text('Göğüs'), findsOneWidget);
  });

  testWidgets('Programlar ekranında seçilen program etkin olur', (tester) async {
    await seedProgram();
    await programs.createProgram('Tam vücut');
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Programlar'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramsScreen), findsOneWidget);

    await tester.tap(find.text('Tam vücut'));
    await tester.pumpAndSettle();

    expect(find.byType(ProgramsScreen), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Tam vücut')),
      findsOneWidget,
    );
  });

  testWidgets('etkin program yoksa seçim bilgisi ve Programlar düğmesi görünür', (tester) async {
    await seedProgram();
    final active = (await programs.getActiveProgramDetail())!.program;
    await programs.createProgram('Tam vücut');
    await programs.deleteProgram(active.id);

    await pumpScreen(tester);

    expect(find.text('Etkin program yok'), findsOneWidget);
    await tester.tap(find.text('Programlar'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramsScreen), findsOneWidget);
  });

  testWidgets('360 × 780, yazı 1.3 iken taşma yok', (tester) async {
    await seedProgram();
    await pumpScreen(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.text('Göğüs'), findsOneWidget);
  });
}
