import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/core/widgets/muscle_group_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('kas grubu etiketini gösterir', (tester) async {
    await tester.pumpWidget(_wrap(
      const MuscleGroupChip(group: MuscleGroup.chest),
    ));

    expect(find.text('Göğüs'), findsOneWidget);
  });

  testWidgets('dokunulunca onTap çağrılır', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_wrap(
      MuscleGroupChip(
        group: MuscleGroup.back,
        onTap: () => tapped++,
      ),
    ));

    await tester.tap(find.text('Sırt'));
    expect(tapped, 1);
  });

  testWidgets('onTap yokken dokunulabilir değildir', (tester) async {
    await tester.pumpWidget(_wrap(
      const MuscleGroupChip(group: MuscleGroup.legs),
    ));

    expect(
      find.descendant(
        of: find.byType(MuscleGroupChip),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });
}
