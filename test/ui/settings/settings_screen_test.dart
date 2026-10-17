import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/core/theme/theme_controller.dart';
import 'package:exercise_tracking_app/ui/settings/settings_screen.dart';

import '../../fakes/fake_settings_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  Future<ThemeController> pumpSettings(
    WidgetTester tester, {
    AppThemeId initialTheme = AppThemeId.defaultTheme,
  }) async {
    final controller = ThemeController(
      FakeSettingsRepository(initialTheme: initialTheme),
    );
    await controller.load();
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeController>.value(
        value: controller,
        child: Builder(
          builder: (context) {
            return MaterialApp(
              theme: context.watch<ThemeController>().theme,
              home: const SettingsScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('dört tema adı görünür', (tester) async {
    await pumpSettings(tester);

    for (final id in AppThemeId.values) {
      expect(find.text(id.label), findsOneWidget);
    }
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
  });

  testWidgets('seçili temada onay ikonu görünür', (tester) async {
    await pumpSettings(tester, initialTheme: AppThemeId.yellowNavy);

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('başka temaya dokununca themeId değişir', (tester) async {
    final controller = await pumpSettings(tester);

    expect(controller.themeId, AppThemeId.defaultTheme);

    await tester.tap(find.text(AppThemeId.lightBlue.label));
    await tester.pumpAndSettle();

    expect(controller.themeId, AppThemeId.lightBlue);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
