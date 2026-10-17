import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_palette.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAppTheme', () {
    for (final id in AppThemeId.values) {
      group(id.name, () {
        final palette = AppPalette.of(id);
        final theme = buildAppTheme(id);

        test('brightness ve renkler palete eşit', () {
          expect(theme.brightness, palette.brightness);
          expect(theme.colorScheme.primary, palette.primary);
          expect(theme.scaffoldBackgroundColor, palette.background);
          expect(theme.colorScheme.onSurfaceVariant, palette.muted);
        });

        test('Material 3 açık', () {
          expect(theme.useMaterial3, isTrue);
        });

        test('yazı tipleri doğru aileden', () {
          expect(theme.textTheme.headlineMedium!.fontFamily, 'Oswald');
          expect(theme.textTheme.titleLarge!.fontFamily, 'Oswald');
          expect(theme.textTheme.titleMedium!.fontFamily, 'Oswald');
          expect(theme.textTheme.bodyLarge!.fontFamily, 'Inter');
          expect(theme.textTheme.bodyMedium!.fontFamily, 'Inter');
          expect(theme.textTheme.labelLarge!.fontFamily, 'Inter');
        });

        test('filled buton minimum boyutu 48', () {
          final size = theme.filledButtonTheme.style!.minimumSize!
              .resolve(<WidgetState>{});
          expect(size, const Size(48, 48));
        });
      });
    }

    test('koyu temalar koyu, açık tema açık', () {
      expect(buildAppTheme(AppThemeId.darkOrange).brightness, Brightness.dark);
      expect(buildAppTheme(AppThemeId.redBlack).brightness, Brightness.dark);
      expect(buildAppTheme(AppThemeId.yellowNavy).brightness, Brightness.dark);
      expect(buildAppTheme(AppThemeId.lightBlue).brightness, Brightness.light);
    });
  });
}
