import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/core/widgets/empty_state.dart';
import 'package:exercise_tracking_app/ui/core/widgets/muscle_group_chip.dart';
import 'package:exercise_tracking_app/ui/exercise_detail/exercise_detail_screen.dart';
import 'package:exercise_tracking_app/ui/exercises/exercises_screen.dart';
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

  Future<void> pumpScreen(
    WidgetTester tester, {
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
        value: repository,
        child: MaterialApp(
          theme: buildAppTheme(AppThemeId.darkOrange),
          home: const ExercisesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedCatalog() async {
    await repository.createExercise('Şınav', MuscleGroup.chest);
    await repository.createExercise('Plank', MuscleGroup.core);
    await repository.createExercise('Squat', MuscleGroup.legs);
  }

  testWidgets('hareketler ve kas grubu etiketleri görünür', (tester) async {
    await seedCatalog();

    await pumpScreen(tester);

    expect(find.text('Hareketler'), findsOneWidget);
    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('Şınav'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.widgetWithText(MuscleGroupChip, 'Göğüs'), findsOneWidget);
    expect(find.widgetWithText(MuscleGroupChip, 'Karın'), findsOneWidget);
    expect(find.widgetWithText(MuscleGroupChip, 'Bacak'), findsOneWidget);
  });

  testWidgets('arama listeyi filtreler', (tester) async {
    await seedCatalog();
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'sinav');
    await tester.pumpAndSettle();

    expect(find.text('Şınav'), findsOneWidget);
    expect(find.text('Plank'), findsNothing);
    expect(find.text('Squat'), findsNothing);
  });

  testWidgets('eşleşme yoksa "Eşleşen hareket yok" görünür', (tester) async {
    await seedCatalog();
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Eşleşen hareket yok'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('boş katalogda "Henüz hareket yok" görünür', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Henüz hareket yok'), findsOneWidget);
    expect(
      find.text('Antrenmana hareket eklediğinde burada listelenir.'),
      findsOneWidget,
    );
  });

  testWidgets('bir harekete dokununca detay ekranı açılır', (tester) async {
    await seedCatalog();
    await pumpScreen(tester);

    await tester.tap(find.text('Plank'));
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    final detailAppBar = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Plank'),
    );
    expect(detailAppBar, findsOneWidget);
  });

  testWidgets('telefon boyutunda (360x780, yazı 1.3) uzun ad taşmaz',
      (tester) async {
    await repository.createExercise(
      'Incline Dumbbell Bench Press',
      MuscleGroup.chest,
    );
    await pumpScreen(tester, size: const Size(360, 780), textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.text('Incline Dumbbell Bench Press'), findsOneWidget);
  });

  testWidgets('detayda düzenleyip geri dönünce listede yeni ad görünür', (tester) async {
    await seedCatalog();
    await pumpScreen(tester);

    await tester.tap(find.text('Plank'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hareketi düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Plank Hold');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Plank Hold'), findsOneWidget);
    expect(find.text('Plank'), findsNothing);
  });
}
