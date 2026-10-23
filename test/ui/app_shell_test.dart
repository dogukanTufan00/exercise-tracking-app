import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/measurement_repository.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/ui/app_shell.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/exercise_detail/exercise_detail_screen.dart';
import 'package:exercise_tracking_app/ui/exercises/exercises_screen.dart';
import 'package:exercise_tracking_app/ui/history/history_screen.dart';
import 'package:exercise_tracking_app/ui/profile/profile_screen.dart';
import 'package:exercise_tracking_app/ui/workout/workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../fakes/fake_measurement_repository.dart';
import '../fakes/fake_workout_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  late FakeWorkoutRepository repository;
  late FakeMeasurementRepository measurements;

  setUp(() {
    repository = FakeWorkoutRepository();
    measurements = FakeMeasurementRepository();
  });

  Future<void> pumpShell(
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
          Provider<WorkoutRepository>.value(value: repository),
          Provider<MeasurementRepository>.value(value: measurements),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemeId.darkOrange),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Alt gezinme çubuğundaki bir sekme etiketine dokunur.
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedPlank() async {
    await repository.createExercise('Plank', MuscleGroup.core);
  }

  testWidgets('üç sekme etiketi görünür', (tester) async {
    await pumpShell(tester);

    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Antrenmanlar'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Hareketler'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profil'),
      ),
      findsOneWidget,
    );
    expect(find.byType(HistoryScreen), findsOneWidget);
  });

  testWidgets('Hareketler ve Profil sekmeleri ilgili ekranı gösterir',
      (tester) async {
    await pumpShell(tester);

    await tapTab(tester, 'Hareketler');
    expect(find.byType(ExercisesScreen), findsOneWidget);
    expect(find.byType(HistoryScreen), findsNothing);

    await tapTab(tester, 'Profil');
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(ExercisesScreen), findsNothing);
  });

  testWidgets('hareket detayı sekme değişince açık kalır', (tester) async {
    await seedPlank();
    await pumpShell(tester);

    await tapTab(tester, 'Hareketler');
    await tester.tap(find.text('Plank'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseDetailScreen), findsOneWidget);

    await tapTab(tester, 'Profil');
    expect(find.byType(ExerciseDetailScreen), findsNothing);

    await tapTab(tester, 'Hareketler');
    expect(find.byType(ExerciseDetailScreen), findsOneWidget);
  });

  testWidgets('aktif sekmeye tekrar dokunmak yığını köke döndürür',
      (tester) async {
    await seedPlank();
    await pumpShell(tester);

    await tapTab(tester, 'Hareketler');
    await tester.tap(find.text('Plank'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseDetailScreen), findsOneWidget);

    await tapTab(tester, 'Hareketler');
    expect(find.byType(ExerciseDetailScreen), findsNothing);
    expect(find.byType(ExercisesScreen), findsOneWidget);
  });

  testWidgets('kök sekmede geri ikonu yok', (tester) async {
    await pumpShell(tester);

    await tapTab(tester, 'Hareketler');

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('geri tuşu önce sekmenin yığınında geri gider, sonra sekme 0\'a döner',
      (tester) async {
    await seedPlank();
    await pumpShell(tester);

    await tapTab(tester, 'Hareketler');
    await tester.tap(find.text('Plank'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseDetailScreen), findsNothing);
    expect(find.byType(ExercisesScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.byType(ExercisesScreen), findsNothing);
  });

  testWidgets('Hareketler sekmesine dönünce yeni hareket listede görünür',
      (tester) async {
    await seedPlank();
    await pumpShell(tester);

    await repository.createExercise('Squat', MuscleGroup.legs);
    await tapTab(tester, 'Hareketler');

    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
  });

  testWidgets('Profil sekmesine dönünce yeni ölçüm değeri görünür',
      (tester) async {
    await pumpShell(tester);
    expect(find.text('82 kg'), findsNothing);

    final types = await measurements.getMeasurementTypes();
    final weight = types.firstWhere((t) => t.name == 'Kilo').id;
    await measurements.addMeasurement(
      weight,
      82,
      measuredAt: DateTime(2020, 1, 1, 12),
    );
    await tapTab(tester, 'Profil');

    expect(find.text('82 kg'), findsOneWidget);
  });

  testWidgets('antrenman ekranı açıkken alt gezinme çubuğu görünmez',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byTooltip('Antrenman başlat'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutScreen), findsOneWidget);
    expect(find.byType(NavigationBar).hitTestable(), findsNothing);
  });

  testWidgets('alt gezinme çubuğu 360 × 780, yazı 1.3 iken taşmaz',
      (tester) async {
    await pumpShell(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
