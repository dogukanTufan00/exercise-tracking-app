import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import 'app_palette.dart';
import 'app_spacing.dart';

const String _displayFont = 'Oswald';
const String _bodyFont = 'Inter';

/// Seçilen temadan Material 3 `ThemeData` üretir (bkz. docs/DESIGN.md).
///
/// Renkler [AppPalette] tablosundan birebir alınır; ekranlar değerleri yalnızca
/// `Theme.of(context)` üzerinden okur.
ThemeData buildAppTheme(AppThemeId id) {
  final palette = AppPalette.of(id);
  final isDark = palette.brightness == Brightness.dark;

  final colorScheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.primary,
    onSecondary: palette.onPrimary,
    tertiary: palette.primary,
    onTertiary: palette.onPrimary,
    error: isDark ? const Color(0xFFFF6B6B) : const Color(0xFFC62828),
    onError: isDark ? const Color(0xFF1A0000) : Colors.white,
    surface: palette.background,
    onSurface: palette.onSurface,
    onSurfaceVariant: palette.muted,
    outline: palette.outline,
    outlineVariant: palette.outline,
    surfaceContainerLowest: palette.surface,
    surfaceContainerLow: palette.surface,
    surfaceContainer: palette.surface,
    surfaceContainerHigh: palette.surface,
    surfaceContainerHighest: palette.surface,
  );

  final textTheme = _buildTextTheme(palette, colorScheme);

  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: colorScheme,
    fontFamily: _bodyFont,
    textTheme: textTheme,
    scaffoldBackgroundColor: palette.background,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.headlineMedium,
    ),
    cardTheme: CardThemeData(
      color: palette.background,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: palette.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(palette.primary),
        foregroundColor: WidgetStatePropertyAll(palette.onPrimary),
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(palette.onSurface),
        side: WidgetStatePropertyAll(BorderSide(color: palette.outline)),
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(palette.primary),
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
        ),
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.primary,
      foregroundColor: palette.onPrimary,
      elevation: 0,
      highlightElevation: 0,
      shape: const CircleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: TextStyle(color: palette.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: Colors.transparent,
      secondarySelectedColor: Colors.transparent,
      checkmarkColor: palette.primary,
      side: BorderSide(color: palette.outline),
      shape: StadiumBorder(side: BorderSide(color: palette.outline)),
      labelStyle: textTheme.labelMedium,
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: palette.primary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surface,
      contentTextStyle: TextStyle(color: palette.onSurface),
      actionTextColor: palette.primary,
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(
      color: palette.outline,
      thickness: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}

/// Yazı ölçeği (bkz. docs/DESIGN.md §3). Başlıklar Oswald, geri kalanı Inter.
TextTheme _buildTextTheme(AppPalette palette, ColorScheme colorScheme) {
  final base = Typography.material2021(colorScheme: colorScheme).englishLike.apply(
        bodyColor: palette.onSurface,
        displayColor: palette.onSurface,
      );

  return base.copyWith(
    headlineMedium: _textStyle(_displayFont, 26, FontWeight.w500, palette.onSurface),
    titleLarge: _textStyle(_displayFont, 18, FontWeight.w500, palette.onSurface),
    titleMedium: _textStyle(_displayFont, 18, FontWeight.w500, palette.onSurface),
    bodyLarge: _textStyle(_bodyFont, 15, FontWeight.w400, palette.onSurface),
    bodyMedium: _textStyle(_bodyFont, 15, FontWeight.w400, palette.onSurface),
    bodySmall: _textStyle(_bodyFont, 13, FontWeight.w400, palette.muted),
    labelLarge: _textStyle(_bodyFont, 15, FontWeight.w500, palette.onSurface),
    labelMedium: _textStyle(_bodyFont, 13, FontWeight.w400, palette.muted),
    labelSmall: _textStyle(_bodyFont, 13, FontWeight.w400, palette.muted),
  );
}

/// Değişken font için hem `fontWeight` hem `wght` ekseni verilir.
TextStyle _textStyle(String family, double size, FontWeight weight, Color color) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
  );
}
