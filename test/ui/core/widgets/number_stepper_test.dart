import 'package:exercise_tracking_app/ui/core/widgets/number_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('+ ve - doğru değerle onChanged çağırır', (tester) async {
    double? received;
    await tester.pumpWidget(_wrap(
      NumberStepper(
        value: 60,
        step: 2.5,
        label: 'Ağırlık',
        unit: 'kg',
        onChanged: (v) => received = v,
      ),
    ));

    await tester.tap(find.byIcon(Icons.add));
    expect(received, 62.5);

    await tester.tap(find.byIcon(Icons.remove));
    expect(received, 57.5);
  });

  testWidgets('min değerinde - butonu devre dışı', (tester) async {
    await tester.pumpWidget(_wrap(
      NumberStepper(
        value: 0,
        step: 1,
        min: 0,
        allowDecimal: false,
        label: 'Tekrar',
        onChanged: (_) {},
      ),
    ));

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.remove),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('değere dokununca diyalog açılır ve geçerli değer kabul edilir',
      (tester) async {
    double? received;
    await tester.pumpWidget(_wrap(
      NumberStepper(
        value: 60,
        step: 2.5,
        label: 'Ağırlık',
        unit: 'kg',
        onChanged: (v) => received = v,
      ),
    ));

    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Ağırlık'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '70,5');
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();

    expect(received, 70.5);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('geçersiz girdide hata metni görünür ve diyalog açık kalır',
      (tester) async {
    double? received;
    await tester.pumpWidget(_wrap(
      NumberStepper(
        value: 60,
        step: 2.5,
        label: 'Ağırlık',
        onChanged: (v) => received = v,
      ),
    ));

    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();

    expect(find.text('Geçerli bir sayı girin'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(received, isNull);
  });

  testWidgets('allowDecimal false iken ondalıklı girdi reddedilir',
      (tester) async {
    double? received;
    await tester.pumpWidget(_wrap(
      NumberStepper(
        value: 10,
        step: 1,
        allowDecimal: false,
        label: 'Tekrar',
        onChanged: (v) => received = v,
      ),
    ));

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '8,5');
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bu alanda ondalıklı değer girilemez'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(received, isNull);
  });

  testWidgets('telefon boyutunda yan yana iki stepper taşmaz', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: NumberStepper(
                    value: 60,
                    step: 2.5,
                    unit: 'kg',
                    label: 'Ağırlık',
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NumberStepper(
                    value: 10,
                    step: 1,
                    min: 1,
                    allowDecimal: false,
                    label: 'Tekrar',
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.add), findsNWidgets(2));
  });
}
