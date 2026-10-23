import 'package:exercise_tracking_app/data/repositories/program_repository.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/data/models/app_theme_id.dart';
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

  /// Bir "Aç" düğmesi olan sahne; Programlar ekranı üstüne itilir ve dönülebilir.
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
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const ProgramsScreen()),
                  ),
                  child: const Text('Aç'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('program yoksa boş durum görünür', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Henüz program yok'), findsOneWidget);
  });

  testWidgets('yalnızca etkin program "Etkin" işaretiyle görünür', (tester) async {
    await programs.createProgram('Üst/Alt');
    await programs.createProgram('Tam vücut');

    await pumpScreen(tester);

    expect(find.text('Üst/Alt'), findsOneWidget);
    expect(find.text('Tam vücut'), findsOneWidget);
    expect(find.text('Etkin'), findsOneWidget);
  });

  testWidgets('+ ile yeni program oluşturulur; etkin olmayan kalır', (tester) async {
    await programs.createProgram('Üst/Alt');
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Yeni program'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tam vücut');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Oluştur'));
    await tester.pumpAndSettle();

    expect(find.text('Tam vücut'), findsOneWidget);
    expect(find.text('Etkin'), findsOneWidget);
  });

  testWidgets('bir programa dokunmak onu etkin yapar ve geri döner', (tester) async {
    await programs.createProgram('Üst/Alt');
    await programs.createProgram('Tam vücut');
    await pumpScreen(tester);

    await tester.tap(find.text('Tam vücut'));
    await tester.pumpAndSettle();

    expect(find.byType(ProgramsScreen), findsNothing);
    expect(find.text('Aç'), findsOneWidget);
    final active = (await programs.getPrograms()).singleWhere((p) => p.isActive);
    expect(active.name, 'Tam vücut');
  });

  testWidgets('360 × 780, yazı 1.3 iken taşma yok', (tester) async {
    await programs.createProgram('Çok uzun bir program adı bu satırı taşırabilir');
    await pumpScreen(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);
  });
}
