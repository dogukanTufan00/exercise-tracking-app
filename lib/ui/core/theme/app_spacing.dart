/// Boşluk ve boyut sabitleri (bkz. docs/DESIGN.md §4). Ekranlarda sayı yazmak yerine bunlar kullanılır.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Ekranın sol/sağ kenar boşluğu.
  static const double screenPadding = 16;

  /// Dokunulabilir her öğenin en küçük boyutu (salonda terli elle kullanım).
  static const double minTouchTarget = 48;

  static const double cardRadius = 12;
  static const double buttonRadius = 12;
}
