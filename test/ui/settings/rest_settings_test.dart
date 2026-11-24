import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/rest/rest_controller.dart';
import 'package:exercise_tracking_app/data/repositories/measurement_repository.dart';
import 'package:exercise_tracking_app/data/repositories/program_repository.dart';
import 'package:exercise_tracking_app/data/repositories/settings_repository.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/data/services/backup_file_service.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/core/theme/theme_controller.dart';
import 'package:exercise_tracking_app/ui/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_backup_file_service.dart';
import '../../fakes/fake_measurement_repository.dart';
import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_rest_notifier.dart';
import '../../fakes/fake_rest_store.dart';
import '../../fakes/fake_settings_repository.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  Future<RestController> pumpSettings(
    WidgetTester tester, {
    bool withRest = true,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = FakeSettingsRepository();
    final themes = ThemeController(settings);
    await themes.load();
    final workouts = FakeWorkoutRepository();
    final rest = RestController(
      store: FakeRestStore(),
      settings: settings,
      notifier: FakeRestNotifier(),
    );
    await rest.load();
    addTearDown(rest.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutRepository>.value(value: workouts),
          Provider<SettingsRepository>.value(value: settings),
          Provider<MeasurementRepository>.value(value: FakeMeasurementRepository()),
          Provider<ProgramRepository>.value(value: FakeProgramRepository(workouts)),
          Provider<BackupFileService>.value(value: FakeBackupFileService()),
          ChangeNotifierProvider<ThemeController>.value(value: themes),
          if (withRest) ChangeNotifierProvider<RestController>.value(value: rest),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemeId.darkOrange),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return rest;
  }

  testWidgets('dinlenme süresi varsayılan 1:30 gösterilir ve +/− ile değişir', (tester) async {
    final rest = await pumpSettings(tester);

    expect(find.text('Dinlenme süresi'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);

    await tester.tap(find.byTooltip('Artır'));
    await tester.pumpAndSettle();
    expect(rest.restSeconds, 105);
    expect(find.text('1:45'), findsOneWidget);

    await tester.tap(find.byTooltip('Azalt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Azalt'));
    await tester.pumpAndSettle();
    expect(rest.restSeconds, 75);
    expect(find.text('1:15'), findsOneWidget);
  });

  testWidgets('telefon titreşim anahtarı denetleyiciye yazılır', (tester) async {
    final rest = await pumpSettings(tester);

    expect(find.text('Dinlenme bitince telefon da titresin'), findsOneWidget);
    expect(find.text('Saat her zaman titrer.'), findsOneWidget);
    expect(rest.vibrateOnPhone, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(rest.vibrateOnPhone, isFalse);
  });

  testWidgets('dinlenme denetleyicisi yoksa bölüm gizlenir', (tester) async {
    await pumpSettings(tester, withRest: false);

    expect(find.text('Dinlenme süresi'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });
}
