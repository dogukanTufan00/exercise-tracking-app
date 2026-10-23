import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/program/widgets/target_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Diyaloğu açar; kapanınca dönen değer [captured] listesine eklenir.
Widget _host(ExerciseTarget? initial, List<ExerciseTarget?> captured) {
  return MaterialApp(
    theme: buildAppTheme(AppThemeId.darkOrange),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await showTargetDialog(
                context,
                exerciseName: 'Bench',
                initial: initial,
              );
              captured.add(result);
            },
            child: const Text('aç'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, ExerciseTarget? initial, List<ExerciseTarget?> captured) async {
  await tester.pumpWidget(_host(initial, captured));
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('varsayılan hedef 3 × 10, ağırlık yok; Kaydet onu döndürür', (tester) async {
    final captured = <ExerciseTarget?>[];
    await _open(tester, null, captured);

    expect(find.text('Bench'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('kg'), findsNothing);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(captured, [const ExerciseTarget(sets: 3, reps: 10)]);
  });

  testWidgets('ağırlık anahtarı açılınca ağırlık hedefi kaydedilir', (tester) async {
    final captured = <ExerciseTarget?>[];
    await _open(tester, null, captured);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Ağırlık'), findsOneWidget);

    // 20 kg varsayılan; artırınca 22,5 olur.
    await tester.tap(find.byTooltip('Artır').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(captured.single?.weightKg, 22.5);
    expect(captured.single?.sets, 3);
    expect(captured.single?.reps, 10);
  });

  testWidgets('ağırlık anahtarı kapatılınca weightKg null olur', (tester) async {
    final captured = <ExerciseTarget?>[];
    await _open(tester, const ExerciseTarget(sets: 4, reps: 8, weightKg: 40), captured);

    expect(find.text('Ağırlık'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Ağırlık'), findsNothing);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(captured.single, const ExerciseTarget(sets: 4, reps: 8));
  });

  testWidgets('İptal null döndürür', (tester) async {
    final captured = <ExerciseTarget?>[];
    await _open(tester, null, captured);

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();

    expect(captured, [null]);
  });
}
