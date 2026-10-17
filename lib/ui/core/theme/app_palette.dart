import 'package:flutter/material.dart';

import '../../../data/models/models.dart';

/// Bir temanın renk tablosu (bkz. docs/DESIGN.md §2).
///
/// Ekranlar renkleri doğrudan buradan değil, `Theme.of(context)` üzerinden okur;
/// bu sınıf yalnızca [buildAppTheme] tarafından kullanılır.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.outline,
    required this.onSurface,
    required this.muted,
    required this.primary,
    required this.onPrimary,
  });

  /// Açık ya da koyu tema.
  final Brightness brightness;

  /// Sayfa arka planı.
  final Color background;

  /// Kart, alan ve diyalog yüzeyi.
  final Color surface;

  /// İnce çerçeve ve ayraç rengi.
  final Color outline;

  /// Ana metin rengi.
  final Color onSurface;

  /// Soluk metin (yardımcı metin, etiket).
  final Color muted;

  /// Vurgu rengi.
  final Color primary;

  /// Vurgu rengi üzerindeki metin ve simge rengi.
  final Color onPrimary;

  /// Verilen temanın renk tablosunu döndürür.
  static AppPalette of(AppThemeId id) {
    switch (id) {
      case AppThemeId.darkOrange:
        return const AppPalette(
          brightness: Brightness.dark,
          background: Color(0xFF121212),
          surface: Color(0xFF1E1E1E),
          outline: Color(0xFF2C2C2C),
          onSurface: Color(0xFFF2F2F2),
          muted: Color(0xFF9A9A9A),
          primary: Color(0xFFFF7A1A),
          onPrimary: Color(0xFF1A0E00),
        );
      case AppThemeId.redBlack:
        return const AppPalette(
          brightness: Brightness.dark,
          background: Color(0xFF0B0B0B),
          surface: Color(0xFF191919),
          outline: Color(0xFF2A2A2A),
          onSurface: Color(0xFFF5F5F5),
          muted: Color(0xFF9C9C9C),
          primary: Color(0xFFE5383B),
          onPrimary: Color(0xFFFFFFFF),
        );
      case AppThemeId.yellowNavy:
        return const AppPalette(
          brightness: Brightness.dark,
          background: Color(0xFF0F1B2D),
          surface: Color(0xFF172A44),
          outline: Color(0xFF24395A),
          onSurface: Color(0xFFEEF2F8),
          muted: Color(0xFF93A3BC),
          primary: Color(0xFFFFC93C),
          onPrimary: Color(0xFF1E1600),
        );
      case AppThemeId.lightBlue:
        return const AppPalette(
          brightness: Brightness.light,
          background: Color(0xFFF6F6F4),
          surface: Color(0xFFFFFFFF),
          outline: Color(0xFFE2E2DE),
          onSurface: Color(0xFF1A1A1A),
          muted: Color(0xFF6B6B6B),
          primary: Color(0xFF2F6FEB),
          onPrimary: Color(0xFFFFFFFF),
        );
    }
  }
}
