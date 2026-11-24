import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/rest/rest_controller.dart';
import 'package:exercise_tracking_app/domain/rest_timer.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/workout/widgets/rest_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_rest_notifier.dart';
import '../../fakes/fake_rest_store.dart';
import '../../fakes/fake_settings_repository.dart';

void main() {
  late FakeRestStore store;
  late FakeRestNotifier notifier;
  late RestController controller;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 11, 20, 18, 0, 0);
    store = FakeRestStore(
      rest: RestState(
        restId: 'r1',
        workoutId: 1,
        endsAt: now.add(const Duration(seconds: 90)),
        totalSeconds: 90,
      ),
    );
    notifier = FakeRestNotifier();
    controller = RestController(
      store: store,
      settings: FakeSettingsRepository(),
      notifier: notifier,
      clock: () => now,
    );
  });

  Future<void> pumpBar(WidgetTester tester, {int workoutId = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeId.darkOrange),
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: RestBar(controller: controller, workoutId: workoutId),
        ),
      ),
    );
    await tester.pump();
  }

  /// Ağacı söker (barın zamanlayıcısı iptal edilir) ve denetleyiciyi kapatır (bitiş zamanlayıcısı iptal edilir).
  Future<void> tearDownBar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  }

  testWidgets('kalan süreyi ve düğmeleri gösterir', (tester) async {
    await controller.load();
    await pumpBar(tester);

    expect(find.text('1:30'), findsOneWidget);
    expect(find.text('Dinlenme'), findsOneWidget);
    expect(find.text('−15'), findsOneWidget);
    expect(find.text('+15'), findsOneWidget);
    expect(find.text('Atla'), findsOneWidget);
    await tearDownBar(tester);
  });

  testWidgets('+15 sayacı uzatır ve ekran yeni süreyi gösterir', (tester) async {
    await controller.load();
    await pumpBar(tester);

    await tester.tap(find.text('+15'));
    await tester.pump();
    await tester.pump();

    expect(store.rest?.endsAt, now.add(const Duration(seconds: 105)));
    expect(find.text('1:45'), findsOneWidget);
    await tearDownBar(tester);
  });

  testWidgets('−15 sayacı kısaltır', (tester) async {
    await controller.load();
    await pumpBar(tester);

    await tester.tap(find.text('−15'));
    await tester.pump();
    await tester.pump();

    expect(store.rest?.endsAt, now.add(const Duration(seconds: 75)));
    expect(find.text('1:15'), findsOneWidget);
    await tearDownBar(tester);
  });

  testWidgets('Atla sayacı durdurur ve şerit kaybolur', (tester) async {
    await controller.load();
    await pumpBar(tester);

    await tester.tap(find.text('Atla'));
    await tester.pump();
    await tester.pump();

    expect(store.rest, isNull);
    expect(notifier.cancelCount, greaterThan(0));
    expect(find.text('Dinlenme'), findsNothing);
    await tearDownBar(tester);
  });

  testWidgets('başka antrenmanın sayacında görünmez', (tester) async {
    await controller.load();
    await pumpBar(tester, workoutId: 2);

    expect(find.text('Dinlenme'), findsNothing);
    expect(find.text('Atla'), findsNothing);
    await tearDownBar(tester);
  });

  testWidgets('zaman geçince kalan süre yenilenir', (tester) async {
    await controller.load();
    await pumpBar(tester);

    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('1:00'), findsOneWidget);
    await tearDownBar(tester);
  });
}
