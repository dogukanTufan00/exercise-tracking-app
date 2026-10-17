import 'package:exercise_tracking_app/ui/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('başlık ve mesajı gösterir', (tester) async {
    await tester.pumpWidget(_wrap(
      const EmptyState(
        icon: Icons.fitness_center,
        title: 'Henüz antrenman yok',
        message: 'Yaptığın antrenmanlar burada listelenir.',
      ),
    ));

    expect(find.text('Henüz antrenman yok'), findsOneWidget);
    expect(
      find.text('Yaptığın antrenmanlar burada listelenir.'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('etiket ve callback verilince buton görünür ve çalışır',
      (tester) async {
    var pressed = 0;
    await tester.pumpWidget(_wrap(
      EmptyState(
        icon: Icons.fitness_center,
        title: 'Henüz antrenman yok',
        message: 'İlk antrenmanını başlat.',
        actionLabel: 'Antrenman başlat',
        onAction: () => pressed++,
      ),
    ));

    expect(find.text('Antrenman başlat'), findsOneWidget);
    await tester.tap(find.text('Antrenman başlat'));
    expect(pressed, 1);
  });

  testWidgets('yalnızca etiket verilirse buton görünmez', (tester) async {
    await tester.pumpWidget(_wrap(
      const EmptyState(
        icon: Icons.fitness_center,
        title: 'Başlık',
        message: 'Mesaj',
        actionLabel: 'Başlat',
      ),
    ));

    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('yalnızca callback verilirse buton görünmez', (tester) async {
    await tester.pumpWidget(_wrap(
      EmptyState(
        icon: Icons.fitness_center,
        title: 'Başlık',
        message: 'Mesaj',
        onAction: () {},
      ),
    ));

    expect(find.byType(FilledButton), findsNothing);
  });
}
