import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_palette.dart';
import 'package:exercise_tracking_app/ui/core/theme/theme_controller.dart';

import '../../../fakes/fake_settings_repository.dart';

void main() {
  group('ThemeController', () {
    test('load öncesi varsayılan temayı kullanır', () {
      final controller = ThemeController(FakeSettingsRepository());

      expect(controller.themeId, AppThemeId.defaultTheme);
    });

    test('load kayıtlı temayı okur ve dinleyicileri bilgilendirir', () async {
      final controller = ThemeController(
        FakeSettingsRepository(initialTheme: AppThemeId.yellowNavy),
      );
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.load();

      expect(controller.themeId, AppThemeId.yellowNavy);
      expect(notified, 1);
      controller.dispose();
    });

    test('setTheme durumu günceller, dinleyicileri bilgilendirir ve kaydeder', () async {
      final repository = FakeSettingsRepository();
      final controller = ThemeController(repository);
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setTheme(AppThemeId.lightBlue);

      expect(controller.themeId, AppThemeId.lightBlue);
      expect(notified, 1);
      expect(repository.savedThemeIds, [AppThemeId.lightBlue]);
      controller.dispose();
    });

    test('theme seçili paletin primary rengini kullanır', () async {
      final controller = ThemeController(FakeSettingsRepository());

      await controller.setTheme(AppThemeId.redBlack);

      expect(
        controller.theme.colorScheme.primary,
        AppPalette.of(AppThemeId.redBlack).primary,
      );
      expect(controller.theme.brightness, Brightness.dark);
      controller.dispose();
    });

    test('dispose sonrası load dinleyicileri bilgilendirmez', () async {
      final controller = ThemeController(
        FakeSettingsRepository(initialTheme: AppThemeId.redBlack),
      );
      var notified = 0;
      controller.addListener(() => notified++);

      final loading = controller.load();
      controller.dispose();
      await loading;

      expect(notified, 0);
    });
  });
}
