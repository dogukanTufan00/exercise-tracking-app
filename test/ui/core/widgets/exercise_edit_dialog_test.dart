import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/core/widgets/exercise_edit_dialog.dart';
import 'package:exercise_tracking_app/ui/core/widgets/muscle_group_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final curl = Exercise(id: 1, name: 'Biceps curl', muscleGroup: MuscleGroup.legs);

  /// Diyaloğu açan bir düğme içeren ekran; her sonuç [results]'a eklenir.
  late List<ExerciseEdit?> results;

  setUp(() {
    results = [];
  });

  Future<void> pumpHost(
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
      MaterialApp(
        theme: buildAppTheme(AppThemeId.darkOrange),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  results.add(await showExerciseEditDialog(context, curl));
                },
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
  }

  TextField nameField(WidgetTester tester) {
    return tester.widget<TextField>(find.byType(TextField));
  }

  testWidgets('mevcut ad ve kas grubu seçenekleriyle açılır', (tester) async {
    await pumpHost(tester);
    await openDialog(tester);

    expect(find.text('Hareketi düzenle'), findsOneWidget);
    expect(find.text('Ad'), findsOneWidget);
    expect(find.text('Kas grubu'), findsOneWidget);
    expect(nameField(tester).controller!.text, 'Biceps curl');
    expect(find.byType(MuscleGroupChip), findsNWidgets(MuscleGroup.values.length));
  });

  testWidgets('ad ve kas grubu değişip Kaydet değerleri döndürür', (tester) async {
    await pumpHost(tester);
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), '  Dumbbell Curl ');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MuscleGroupChip, 'Kol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(results, [(name: 'Dumbbell Curl', muscleGroup: MuscleGroup.arms)]);
    expect(find.text('Hareketi düzenle'), findsNothing);
  });

  testWidgets('İptal null döndürür', (tester) async {
    await pumpHost(tester);
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'Değişti');
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('ad boşken Kaydet devre dışıdır', (tester) async {
    await pumpHost(tester);
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Kaydet'));
    expect(save.onPressed, isNull);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.text('Hareketi düzenle'), findsOneWidget);
  });

  testWidgets('telefon boyutunda (360x780, yazı 1.3) taşma olmaz', (tester) async {
    await pumpHost(tester, size: const Size(360, 780), textScale: 1.3);
    await openDialog(tester);

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(MuscleGroupChip, 'Diğer'), findsOneWidget);
  });
}
