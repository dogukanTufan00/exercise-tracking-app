import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/core/widgets/empty_state.dart';
import 'package:exercise_tracking_app/ui/core/widgets/muscle_group_chip.dart';
import 'package:exercise_tracking_app/ui/exercise_picker/exercise_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_workout_repository.dart';

/// Ekranı bir "aç" butonunun altından push eder ve dönen değeri [onResult]'a verir.
Widget _host(WorkoutRepository repository, ValueChanged<Exercise?> onResult) {
  return Provider<WorkoutRepository>.value(
    value: repository,
    child: MaterialApp(
      theme: buildAppTheme(AppThemeId.darkOrange),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push<Exercise>(
                  context,
                  MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
                );
                onResult(result);
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Ekranı açar; dönen değer `captured` listesine eklenir.
Future<void> _openPicker(
  WidgetTester tester,
  WorkoutRepository repository,
  List<Exercise?> captured,
) async {
  await tester.pumpWidget(_host(repository, captured.add));
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  testWidgets('listedeki harekete dokununca o hareketle kapanır', (tester) async {
    final repository = FakeWorkoutRepository();
    await repository.createExercise('Şınav', MuscleGroup.chest);
    final plank = await repository.createExercise('Plank', MuscleGroup.core);
    final captured = <Exercise?>[];

    await _openPicker(tester, repository, captured);

    expect(find.text('Hareket seç'), findsOneWidget);
    await tester.tap(find.text('Plank'));
    await tester.pumpAndSettle();

    expect(captured, [plank]);
    expect(find.text('Hareket seç'), findsNothing);
  });

  testWidgets('yeni ad, kas grubu ve Ekle ile yeni hareketle kapanır', (tester) async {
    final repository = FakeWorkoutRepository();
    await repository.createExercise('Şınav', MuscleGroup.chest);
    final captured = <Exercise?>[];

    await _openPicker(tester, repository, captured);

    await tester.enterText(find.byType(TextField), 'Yeni Hareket');
    await tester.pumpAndSettle();

    expect(find.text('"Yeni Hareket" adıyla yeni hareket'), findsOneWidget);

    final addButton = find.widgetWithText(FilledButton, 'Ekle');
    expect(tester.widget<FilledButton>(addButton).onPressed, isNull);

    await tester.tap(find.widgetWithText(MuscleGroupChip, 'Bacak'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(addButton).onPressed, isNotNull);

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(captured, hasLength(1));
    expect(captured.single?.name, 'Yeni Hareket');
    expect(captured.single?.muscleGroup, MuscleGroup.legs);
    expect(find.text('Hareket seç'), findsNothing);
  });

  testWidgets('boş katalogda boş durum görünür', (tester) async {
    final repository = FakeWorkoutRepository();
    final captured = <Exercise?>[];

    await _openPicker(tester, repository, captured);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Kataloğun boş'), findsOneWidget);
    expect(find.text('Yukarıya bir hareket adı yazarak ilk hareketini ekle.'),
        findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ekle'), findsNothing);
  });
}
